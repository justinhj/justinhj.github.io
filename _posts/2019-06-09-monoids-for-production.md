---
layout: post
title:  Monoids for Production
date:   2019-06-05 00:00:00 -0000
tags:
- scala
- functional programming
- monoids
- pure functional programming
---

This post introduces Monoids, first as an abstraction and then as used in some production code to simplify a real programming task. We'll also see how to use Monoid implementations in both the Scalaz and Cats libraries and how to easily write tests that ensure your own instances of Monoids are 'lawful'.

_Example source code_
- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

## Why algebraic structures?

New words can make something simple sound like something complex, but the trade off is that we can use terms that have a precise meaning in other discplines such as group theory and category theory, and implement them in such a way that we can provide the same guarantees and expressive power that they have in the mathematical world to our own progams. We will talk about Semigroups and Monoids here, and both concepts encode simple operations that we do everyday, whether we program in C# or Python or Java. 

I encourage you to 

## Semigroups

A semigroup is an algebra that has a binary associative operation; a function that takes two values of the same type and combines them into a single value.

Integer addition, for example, forms a semigroup:

```scala
def plus(a: Int, b: Int) : Int = a + b

plus(plus(1,2),3) 
//res1: Int = 6

plus(1,plus(2,3)) 
// res2: Int = 6
```

Note that as long as we don't change the order in which the additions are performed, we get the same result. It is this property, associativity, that makes addition with integers a semigroup. Multiplication works the same way:

```scala
def multiply(a: Int, b: Int) : Int = a * b

multiply(multiply(1,2),3) 
//res1: Int = 6

multiply(1,multiply(2,3)) 
// res2: Int = 6
```

Another example that follows the Semigroup pattern is joining strings together. Take the following strings:

`"Hello" "," "World" "!"`

As long as we don't rearrange the strings, we can append them in any order we like and get the same final result. Imagine 4 strings a,b,c and d:

```
a b c d
ab cd
abcd
```

```
a b c d
ab c d
abc d
abcd
```

```
a b c d
a b cd
a bcd
abcd
```

We can do the actual operation in any order and get the same result, which is captured by the property:

`op(op(x,y), z) == op(x, op(y,z))`

## Monoids

Monoids have an additional operation that just returns zero. Zero is some value that can be combined with other values without changing the original value. Here are some examples:

Integer addition - the zero value is 0
```
3 + 0 == 3
0 + 3 == 3
```

Logication or - the zero value is true
```
true || true == true
false || true == true
```

String append - the zero value is the empty string ""
```
"Justin" ++ "" = "Justin"
```

## Monoids in Scala

As I mentioned earlier, we can describe Monoids as a Scala type class which means we will encode its operations as a trait, similar to a Java interface. Note that this implementation is completely abstract:

```scala
trait SemiGroup[A] {
	def op(a: A, b: A) : A
}

trait Monoid[A] extends SemiGroup[A] {
	def zero : A
}

val intMultiply = new Monoid[Int] {
    def zero = 1
	def op(a: Int, b: Int) : Int = (a * b)
}

intMultiply.op(10,20) 
// res1: Int = 200

intMultiply.op(10,intMultiply.zero) 
//res2: Int = 10
```

Whilst nothing stops us from creating our own, we can use the pure functional libraries definition of Monoid instead. This gives us premade instances for many common types as well, syntactic sugar to make working with Monoids more concise, a bunch of useful functions that we can use with monoids like fold and even automated tests that verify our own instances obey the laws.

Let's have a look at Scalaz for example:

```scala
import scalaz._, Scalaz._

val l1 = 10 |+| 20 |+| 30 
//res1: Int = 60 

Foldable[List].fold(l1)
//res2: Int = 60
```

In the example we first use the Monoid combine function using the syntax helper |+| and in the second we use the Scalaz foldable instance for list to do the same job. It knows that we have an implicit monoid instance for adding integers so it uses that.

So addition is the default monoid instance for integers but we could also define multiplication (or any other associative operation) and use that instead. For example, Scalaz has a Tag feature which lets us change the datatype of a thing at compile time only, and it can then pick up a different monoid implementation.

```scala
l1.foldMap{a => Tags.Multiplication(a)}
// res3: Int @@ Tags.Multiplication = 6000
```

Note that we could also just put a locally scoped implicit that had the multiplication instance, but that would break type class coherence. See FP for Mortals for more on Tags and type class coherence.

## Monoids in Production

You already know how to append strings and add numbers, why bother with all this fancy abstraction? Well, first of all we saw above how having a Monoid implementation enables us to use a wider range of combinators like folds and traversals; our intentions are made clearer with less code. When it comes to our application business objects, that may have more complicated append methods and be nested in multiple data structures, we can see that the expressive power of Monoids is a great advantage over an imperative solution. Let's take a look at a real example.

In many MMOG (massively multiplayer online games) you manage a city that contains plots of farm land that produce food, oil and so on. On the backend we need to store the things that the player owns in a database. When in memory we represent the
 inventory as a map, where the keys are the types of resources we own, and the values are the quantity.
 
For example we represent the players resources using integer ids:

1. Oil
2. Gold
3. Corn
 
 A player with just some gold would have an inventory like this:
 

```scala
val inventory = Map(2 -> 1000)
 ```

Now using one of the pure fp libraries, Scalaz or Cats, we can import the relavent libraries and we will get Monoid instances for some types. At least those types for which a lawful Monoid makes sense; happily a Map is one such type. So when we want to add or subtract resources from the player we can do so by using Monoid combine:

```scala
import cats._
import cats.data._
import cats.implicits._

val updatedInventory = inventory.combine(Map(1 -> 20)).combine(Map(3 -> 20)).combine(Map(2 -> -400)) 
// Map(1 -> 20, 2 -> 600, 3 -> 20)
```

In this example we reduced the gold by 400 and granted the player 20 of two types of resources. Because there is an implementation of map for Monoid, we don't have to write our own code to manage iterating over the map, creating missing item keys, summing the values, this is all taken care of. The `|+|` syntax makes it much more readble too:

```scala
val updatedInventory = inventory |+| Map(1 -> 20) |+| Map(3 -> 20) |+| Map(2 -> -400)`
```

Note that the values in the map must have a Monoid instance (in this case the monoid implements int addition). For example we could combine two maps of string values and they would be appended:

```scala
Map(1 -> "Hello") |+| Map(1 -> " ") |+| Map(1 -> "World")
//  Map(1 -> "Hello World")
```




 

