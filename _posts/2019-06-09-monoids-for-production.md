---
layout: post
title:  Monoids for Production
date:   2019-06-05 00:00:00 -0000
tags:
- scala
- functional programming
- monoids
- pure functional programming
- scalaz
- typelevel
- cats
---

This post introduces Monoids, first at an abstract level and then as implemented in Scala and the Scalaz or Cats pure functional programming libraries. Next, I'll show how I used Monoids in production code, on a video game backend, to simplify the code that handles player items that are produced over time.

![ProductionItems](/../images/madlands_production.jpg)

_The code for this post can be found here:_
- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

### Category Theory and Scala

If you've already read a few Monoid tutorials, you may want to skip to [Monoids in Production](#production).

Lifting abstract algebraic structures like Semigroup and Monoid from mathematics can make simple concepts sound complicated. While it would be tempting to come up with new words that sound more familiar, it pays for us to adopt these terms because they let us talk precisely about the things in terms of their operations and laws. It is useful for us to have a shared vocabulary with which we can communicate to other programmers and our compilers, what our types can, and cannot, do.

To read more on pure functional programming in Scala I recommend Functional Programming in Scala [^1]. A newer book that focuses on Scalaz and building a web application is also really good: Functional Programming for Mortals [^2] Finally, for getting started with Cats there is Advanced Scala [^3].

### Semigroups

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

This property is useful because we know that we can do optimisations. If we have long lists of integers we can divide them into smaller ones, run the appends in parallel, and the combine the results. We can use a left fold or a right fold without worrying about the order of operations. 

```scala
Foldable[List].foldLeft(List(1,2,3), 0){_ |+| _} 
//res1: Int = 6
Foldable[List].foldRight(List(1,2,3), 0){_ |+| _}
//res2: Int = 6
```

Note that to fold a list we need the list, a binary operation to combine each element, and a "zero" value. Without a zero value it's impossible to combine all the elements of the list into an accumulator. For example if we have a list with a single item, the first step of the foldLeft would be:

```scala
Foldable[List].foldLeft(List(1), ???){_ |+| _} 
??? |+| 1
```

If we had a zero value available for the type our semigroup is defined for, we could run a fold using that zero value instead of passing it ourselves. The syntax would then be simply:

```scala
Foldable[List].fold(List(1,2,3)) 
//res1: Int = 6
```

By adding a way to get a zero for a type, we turn a semigroup into a monoid.

## Monoids

Although it's called zero, it is not always the number zero. Zero is some value that can be combined with other values without changing the original value. Here are some examples:

Integer addition - the zero value is actually 0
```
3 + 0 == 3
0 + 3 == 3
```

Integer multiplication - the zero value is now 1
```
3 * 1 == 3
1 * 3 == 3
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

### Monoids in Scala

In Scala we can implement Monoids as a Scala type class, a way to extend the behaviour of existing types. We will encode its operations as a trait. Note that this is an abstract definition. We will then define instances of Monoids that make concrete versions of the operations.

```scala
trait SemiGroup[A] {
	def op(a: A, b: A) : A
}

trait Monoid[A] extends SemiGroup[A] {
	def zero : A
}
```

And a sample instance implementation:

```scala
val intMultiply = new Monoid[Int] {
    def zero = 1
	def op(a: Int, b: Int) : Int = (a * b)
}

intMultiply.op(10,20) 
// res1: Int = 200

intMultiply.op(10,intMultiply.zero) 
//res2: Int = 10
```

In our production code, we'll use the Scalaz and Cats Monoid implementations instead of rolling our own. This gives us premade instances for many common types, syntactic sugar to make working with Monoids more concise, a bunch of useful combinators that we can use like fold and even automated law tests that verify our own instances obey the laws.

Let's have a look at Scalaz for example:

```scala
import scalaz._, Scalaz._

val l1 = 10 |+| 20 |+| 30 
//res1: Int = 60 

Foldable[List].fold(List(10,20,30))
//res2: Int = 60
```

In the example we first use the Monoid combine function using the syntax helper `|+|` and in the second we use the Scalaz `foldable` instance for list to do the same job. There is a Monoid instance defined for integer that implements addition, so that is used.

We could also define multiplication (or any other associative operation) and use that instead. For example, Scalaz has a Tag feature which lets us change the datatype of a thing at compile time only, and it can then pick up a different monoid implementation. `Tags.Multiplication` is a tag for numbers that has a Monoid instance that multiplies:

```scala
l1.foldMap{a => Tags.Multiplication(a)}
// res3: Int @@ Tags.Multiplication = 6000
```

Note that we use `foldMap` instead of `fold` here because we need to map a function over the list to add the multiplication tag. We could also just put a locally scoped implicit monoid for multiplication, but that would break type class coherence. See FP for Mortals for more on Tags and type class coherence. In Cats there is no Tags mechanism so you must find other ways to get your alternate implementations in scope.

Finally one more example from my sample code `MaxMonoid.scala`, a Monoid instance for the maximum of two numbers:

```scala
implicit val maxIntMonoid : Monoid[Int] = Monoid.instance[Int]({case (a : Int,b :  Int) => Math.max(a,b)} , Int.MinValue)

val testAppend =  10 |+| 20
// res1: 20
```

Once defined for Int we can then use the fold over a list:

```scala
val ilist = List[Int](1,2,3,4,5,4,3,2,1,-10,1,2,3)
Foldable[List].fold(ilist)
// res1: 5
```

<a name="production"></a>
### Monoids in Production 

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

### Summary

This has been a small sample of how Monoids can help simplify your code, and make easier to compose. Thank you for reading this post, please let me know via the links at the top if you have any questions or comments!

### Footnotes

[^1]: [Functional Programming in Scala](https://www.manning.com/books/functional-programming-in-scala) (the Red Book) by Runar Bjarnsen and Paul Chiusano covers functional programming from first principles as you build your own implementations of immutable lists and options, before showing how to develop useful libraries in a pure functional style. Examples include a json parser and concurrency library. Next we are guided through all of the most common type classes like Functor, Monad, Applicative... what are their laws, what operations can be implemented. Finally we are shown how to control side effects using the IO Monad and the book ends with a sophisticated streaming IO implementation. Manning Publications now have a "livebook" version of the book where you can complete the (essential) exercises directly on the web page as you read.
[^2]: [Functional Programming for Mortals](https://leanpub.com/fpmortals) by Sam Haliday is a practical and principiled guide to building systems with Scala using Scalaz. A real world example application is developed throughout the book, which also functions as a manual to Scalaz, demonstrating each type class in some realistic scenario. It will also appeal to Star Wars fans as Sam helpfully tells us what symbols like `|+|`, `<+>` and `@@` represent both in Scalaz and in the Star Wars universe. Whilst aimed at mortals it will require some experience in Scala to hit the ground running.
[^3]: [Advanced Scala for Cats](https://books.underscore.io/scala-with-cats/scala-with-cats.html) by Noel Walsh and Dave Gurnell is a lighter book than the other two but covers the common type classes clearly and concisely. Rather than covering one big example application, small but realistic examples are given for the various features. Obviously from the title this focuses on the Cats library. Like the red book, this also contains exercises, althought they are not as rigorous or as difficult. This book accompanies Underscores training course.
