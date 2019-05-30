---
layout: post
title:  "Putting Monoids together"
date:   2019-05-27 00:00:00 -0000
tags:
- scala
- functional programming
- monoid
---

The code in this post can be found in a complete Scala project here:

- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

## Algebraic Structures

In Scala, when practising pure functional programming, we borrow ideas from mathematics in order to describe algebraic relationships. Unfortunately, mathematical terms like Monad, Monoid and Functor, tend to give the impression we're dealing with something complicated. In fact, these algebraic structures are quite simple, and just like when we expand our vocabulary in a human language, we are able to express ourselves more richly and concisely in programming languages when we share these patterns with our compilers, and with other engineers.

In this post, I'll talk about Semigroups and Monoids; the definition, their laws and an example of how they can be used in a real program. If you're a Scala or Java programmer with some interest in pure functional programming, I hope you find this interesting. 

A semigroup is simply a type that has a binary associative operation. Which means we have a function taking two arguments of the same type and returning a single result, also of the same type. Some examples:

Integer addition forms a semigroup:

```scala
def plus(a: Int, b: Int) : Int = a + b

plus(plus(1,2),3) 
//res1: Int = 6

plus(1,plus(2,3)) 
// res2: Int = 6
```

Note that as long as we don't change the order in which the things are added together, we get the same result. It is this property, associativity, that makes addition with integers a semigroup. Multiplication works the same way:

```scala
def multiply(a: Int, b: Int) : Int = a * b

multiply(multiply(1,2),3) 
//res1: Int = 6

multiply(1,multiply(2,3)) 
// res2: Int = 6
```

To be a semigroup the function must obey some laws. It is by adhering to these laws that an algebraic structure allows us to make assumptions about its behaviour. 

However, once you put aside the unfamiliar words, these things are not only quite simple, but they give our programs a principled theoretic grounding. Just like when we extend our vocabulary, we can communicate our ideas with precision and more conscisely.

Monoids, for example, are one of the simplest algebraic sturctures. They describe the 

...

Another example that follows the Monoid pattern is joining strings together. Take the following strings:

`"Hello" "," "World" "!"`

As long as we don't rearrange the strings, we can append them in any order we like and get the same final result

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

This means that programs working with monoids know that they can rearrange the append operations to be more efficient, to run them in parallel and so on.

## Monoids in the wild

Maybe so far this seems a little too abstract. You already know how to append strings and sum numbers, why bother with all this fancy abstraction? Well, first of all we saw above how having a Monoid implementation enables us to use a wider range of combinators like folds and traversals; our intentions are made clearer with less code. When it comes to our application business objects, that may have more complicated append methods and be nested in multiple data structures, we can see that the expressive power of Monoids is a great advantage over an imperative solution. Let's take a look at a real example.

Recently I worked with a team of Scala developers on a backend for a China based gaming company IGG. In many MMOG (massively multiplayer online games) you manage a city that contains plots of farm land that produce food, oil and so on. On the backend we need to store the things that the player owns in a database. When in memory we represent the
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




 

