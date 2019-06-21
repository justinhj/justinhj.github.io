---
layout: post
title:  Comonads for Life
date:   2019-06-20 00:00:00 -0000
tags:
- scala
- functional programming
- comonads
- pure functional programming
- typelevel
- cats
---

This post is aimed at the Scala programmer with some experience pure functional programming. We will look at Comonads, a type class closely related to Monads, firstly from an abstract point of view and then a more concrete example, implementing Conway's Game of Life and animating in the terinal. 

_The code for this post can be found here:_
- [https://github.com/justinhj/comonad](https://github.com/justinhj/comonad)

### Monads

To explain comonads, a good place to start is how they relate to monads. In order to get from monad to comonad, we define operations that are the `dual` of those in monad. By dual, we mean that the direction of the data flows is reversed.

The Functor type class has a single operation `map` which lets us take a pure function that converts pure values `A` to pure values of type `B`, and se you can see from the type signature it does so in some context `F`. Examples of a context could be lists, futures (tasks, ios), options. For our simple example we will consider lists of things as our context but bear in mind that contexts are not always simple containers.

```scala
trait Functor[F[_]] {
	def map[A, B](fa: F[A])(f: (A) ⇒ B): F[B]
}
```

Examples of using a map would be to map a list of strings into a list of numbers (the length of those strings)...

```scala
import cats._
import cats.implicits._

List("Hello", ",", "how", " ", "are", "you", "?").map(_.size) 
// List[Int] = List(5, 1, 3, 1, 3, 3, 1)
```

Monads are all Functors, so we can can define it as an extension of Functor, being assured that it has a definition of map. How can we be sure? Well it is possible to implement map using pure and flatmap, we'll see that shortly, which proves that all monads are functors.

Here's the type class definition for Monad.

```scala
trait Monad[F[_]] extends Functor[F] {
	def pure[A](x: A): F[A]
	def flatMap[A, B](fa: F[A])(f: (A) ⇒ F[B]): F[B]
}
```

Aside from map, Monads must implement `pure` which lifts a pure value of type `A` into the effect context `F`. What that means for collection types like list, is that it creates a new collection containing only that element. Generally, implementing pure for a data type involves calling a type constructor for `F`.

```scala
10.pure[List] 
// List[Int] = List(10)
```

`flatmap`, as you can see from the types, takes a pure value `A` in a context `F` and applies a user supplied function to it. The function has the signature `A => F[B]`; in other words functions that take a pure value and lift them into the context. The return value is the new pure value `B` lifted into that same `F` context.

Concretely, imagine a function that takes an integer and returns the digits of the string as a list. That function would match the signature `A => F[B]`.

```scala
def intToDigits(n: Int) = {
    n.toString.toList.map(_.toString.toInt)
}

intToDigits(1001) 
// List[Int] = List(1, 0, 0, 1)
```

Functions that take pure values and return their results lifted into a context are quite common, and often we want to chain the together. If you have a function that takes a user id and has to go to a DB it will likely return something like a `IO[User]`. Often these DB lookups need to be chained together, where each cannot begin until the one before it because it is dependent on some value returned from a previous step. Chaining together effectful functions like this is what flatMap does. To give a concrete example of this chaining we need a second function that we can chain with `intToDigits`.

```scala
def intToRepeat(n: Int) = {
    List.fill(n)(n)
}

intToRepeat(5) 
// List[Int] = List(5, 5, 5, 5, 5)

intToDigits(12345).flatMap(intToRepeat) 
// List[Int] = List(1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5)
```

Just to enforce why we need flatMap here let's look at what happens if we use map instead.

```scala
intToDigits(12345).map(intToRepeat) 
// List[List[Int]] = List(List(1), List(2, 2), List(3, 3, 3), List(4, 4, 4, 4), List(5, 5, 5, 5, 5))
```

As you can see what happened here is we ended up with a nested context `F[F[A]]` instead of what we wanted, `F[A]`. The reason flatMap is so named is that it can be implemented by first mapping each `A` to a `F[A]` giving the `F[F[A]]` then flattening in it to an `F[A]`.

In fact `flatten` is implemented for monad in Cats, and the standard library for that matter, and when we get to comonads it will be helpful to implement it's dual, which we shall call `coflatten`.

We are done with monads for now, but just going back to what I said before about monads being functors, here's how we can implement map in terms of pure and flatmap.

```scala
def map[A,B](n : List[A], f : A => B) : List[B] = n.flatMap(a => f(a).pure[List]) 

map[Int,Int](List(1,2,3), a => a + 1) 
//List[Int] = List(2, 3, 4)
```

### Comonads

From an abstract point of view Monads allow us to chain effects, and to life pure values into effects. Let's now consider Comonads and their dual operations.

```scala
trait Comonad[F[_]] extends Functor[F] {
  def extract[A](x: F[A]): A
  def coflatMap[A, B](fa: F[A])(f: F[A] => B): F[B]
}
```

`extract` is the dual of `pure`. Remember that pure lifts values into a context. The type signature shows us that `extract` instead can reach into the context `F[A]` and give us an `A`. Not all data types have an implementation of extract. Our example of List above does not, because Lists can be empty and the there would be way to extract a value. In pure functional programming we can't simply return null or throw an exception; in order to remain pure we have to return an `A`, so any data types that cannot implement extract do not have Comonad instances.

For our purposes let's switch to `NonEmptyList`, which you can find in Cats and represents a list that cannot be empty. Since it cannot be empty we can always extract a value.

```scala
import cats.data.NonEmptyList

val nel1 = NonEmptyList.of(1,2,3,4,5) 
// NonEmptyList[Int] = NonEmptyList(1, List(2, 3, 4, 5))

nel1.extract 
// Int = 1
```

Extract is quite simple to understand, but `coflatMap` is a bit of a brain teaser. 
