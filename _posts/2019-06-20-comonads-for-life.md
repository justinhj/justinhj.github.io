---
layout: post
title:  Comonads for Life
tags: [scala, functional-programming, comonads, pure-functional-programming, typelevel, cats, zio, popular]
---

![Comonads](/../images/comonads.jpg "Comonads")

This post is aimed at the Scala programmer with some experience pure functional programming with the Cats fp library: [https://typelevel.org/cats/](https://typelevel.org/cats/). We will look at Comonads, a type class closely related to Monads, firstly from an abstract point of view and progressing to a couple of practical, yet simple, examples of using Comonads for interesting applications.

_Example code used in this post is from this github project:_
- [https://github.com/justinhj/comonad](https://github.com/justinhj/comonad/tree/blog-final-2)

_Presentation based on this post from the Vancouver Scala Meetup:_
- [https://justinhj.github.io/comonad-sm-reveal/](https://justinhj.github.io/comonad-sm-reveal/)

## Monads

To explain comonads, a good place to start is how they relate to monads. In order to get from monad to comonad, we define operations that are the `dual` of those in monad. By dual, we mean that the direction of the data flows is reversed.

The Functor type class has a single operation `map` which lets us take a pure function that converts pure values `A` to pure values of type `B`, and as you can see from the type signature it does so in some context `F`. Examples of a context could be lists, asynchronous or deferred calculations (Future, Cats Effect, ZIO, Monix Task) and options. For our simple example we will consider lists of things as our context but bear in mind that contexts are not always simple containers.

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

`flatmap`, as you can see from the types, takes a pure value `A` in a context `F` and applies a user supplied function to it. The function has the signature `A => F[B]`; in other words functions that take a pure value and lifts them into the context. The return value is the new pure value `B` lifted into that same `F` context.

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

## Comonads

From an abstract point of view Monads allow us to chain effects, and to lift pure values into effects. Let's now consider Comonads and their dual operations.

```scala
trait Comonad[F[_]] extends Functor[F] {
  def extract[A](x: F[A]): A
  def coflatMap[A, B](fa: F[A])(f: F[A] => B): F[B]
}
```

`extract` is the dual of `pure`. In some libraries or languages `extract` is known as `counit` (and `pure` is known as `unit`), making the relationship between the two more obvious. Remember that pure lifts values into a context. The type signature shows us that `extract` instead can reach into the context `F[A]` and give us an `A`. Not all data types have an implementation of extract. Our example of List above does not, because Lists can be empty and the there would be no way to extract a value. In pure functional programming we can't simply return null or throw an exception; in order to remain pure we have to return an `A`, so any data types that cannot implement extract do not have Comonad instances.

For our purposes let's switch to `NonEmptyList`, which you can find in Cats and represents a list that cannot be empty. Since it cannot be empty we can always extract a value.

```scala
import cats.data.NonEmptyList

val nel1 = NonEmptyList.of(1,2,3,4,5) 
// NonEmptyList[Int] = NonEmptyList(1, List(2, 3, 4, 5))

nel1.extract 
// Int = 1
```

I found `extract` is simple to understand, but `coflatMap` takes some mental gymnastics to follow. Before we consider that, let's look at `coflatten`, the dual of `flatten`. Remember that `flatten` made it easy for us to implement `flatMap` which requires a way to reduce a nested structure by one level. As you can see from the type signature, a `coflatten` takes a value `A` in a context and returns it in a nested context.

```scala
def coflatten[A](fa: F[A]): F[F[A]]
```

When implementing Comonad's for our own data types we need to make a decision on how to take a structure and create a nested version of it. This is not totally arbitrary, as Comonads have a set of laws like Monads, and so our implementation must satisfy those laws. As we'll see shortly, a way to make a lawful Comonad for NonEmptyList is for the `coflatten` to create a `NonEmptyList[NonEmptyList[A]]]` which is a list of the original list and all of its suffixes (tails).

```scala
val nel1 = NonEmptyList.of(1,2,3,4,5)  
//NonEmptyList[Int] = NonEmptyList(1, List(2, 3, 4, 5))

nel1.coflatten 
// NonEmptyList[NonEmptyList[Int]] = NonEmptyList(
//  NonEmptyList(1, List(2, 3, 4, 5)),
//  List(NonEmptyList(2, List(3, 4, 5)), NonEmptyList(3, List(4, 5)), NonEmptyList(4, List(5)), NonEmptyList(5, List()))
// )
```   
   
One of the comonad laws is the left identity which specifies `fa.coflatten.extract <-> fa`. (All of the laws can be checked using the [ComonadLaws](https://github.com/typelevel/cats/blob/master/laws/src/main/scala/cats/laws/ComonadLaws.scala) in Cats). You can see that this makes sense in terms of the implementation of NonEmptyList above. 

Once we have the `coflatten` implementation for a type we can implement `coflatMap`. Based on the signature `def coflatMap[A, B](fa: F[A])(f: F[A] => B): F[B]` you can see that, just like `extract`, we have just reversed the direction of data flow from `A => F[B]` to `F[A] => B`. That means the caller of the function is going provide a function that gets to look at each suffix of the NonEmptyList and combine each to a single value of type `B`. Those values are returned to the user in a new NonEmptyList. For example taking the size of a NonEmptyList matches the type signature.

```scala
NonEmptyList.of(1,2, 3, 4, 5).coflatMap(_.size) 
//NonEmptyList[Int] = NonEmptyList(5, List(4, 3, 2, 1))
```

Notice that when you flatMap a list, the mapping part looks at the list one element at a time, transforming it to a list. When you coflatMap a list you're looking at the list and all of its tails one by one, collapsing each of them down into a single value.

### Comonad laws

In this section I'll demonstrate each of the Comonad laws in code using `NonEmptyList`.

```scala
val fa = NonEmptyList.of(1,2,3,4) 
// fa: NonEmptyList[Int] = NonEmptyList(1, List(2, 3, 4))
```
Left identity: `fa.coflatten.extract == fa`

```scala
fa.coflatten.extract == fa 
// Boolean = true
```

Right identity: `fa.coflatmap(extract) == fa`

```scala
fa.coflatMap(_.extract) == fa 
// Boolean = true
```

Associativity: `fa.coflatten.coflatten == fa.coflatmap(coflatten)`

```scala
fa.coflatten.coflatten == fa.coflatMap(_.coflatten) 
// Boolean = true
```

Cats contains implementations of checks for these laws which can be found here: [https://github.com/typelevel/cats/blob/master/laws/src/main/scala/cats/laws/ComonadLaws.scala](https://github.com/typelevel/cats/blob/master/laws/src/main/scala/cats/laws/ComonadLaws.scala) You can checkout my last post for how to setup a Scalacheck test for your own datatypes using Cats [Monoids for Production](/2019/06/10/monoids-for-production.html)

## Image processing with a Comonad

I created a data type, `FocusedGrid`, which consists of a 2d grid of values of some type `A` and a focus point which will be a `Tuple2[Int, Int]`. This focus point specifies a row and column of the grid. 

```scala
case class FocusedGrid[A](focus: Tuple2[Int,Int], grid : Vector[Vector[A]])
```

Next we implement the Comomad (and Functor) operations for our new type.

```scala
implicit val focusedGridComonad = new Comonad[FocusedGrid] {
    override def map[A, B](fa: FocusedGrid[A])(f: A => B) : FocusedGrid[B] = {
      FocusedGrid(fa.focus, fa.grid.map(row => row.map(a => f(a))))
    }

    override def coflatten[A](fa: FocusedGrid[A]): FocusedGrid[FocusedGrid[A]] = {
      val grid = fa.grid.mapWithIndex((row, ri) => 
        row.mapWithIndex((col, ci) => 
          FocusedGrid((ri,ci), fa.grid)))
      FocusedGrid(fa.focus, grid)
    }

    // Gives us all of the possible foci for this grid
    def coflatMap[A, B](fa: FocusedGrid[A])(f: FocusedGrid[A] => B): FocusedGrid[B] = {
     val grid = coflatten(fa).grid.map(_.map(col => f(col)))
      FocusedGrid(fa.focus,  grid)
    }

    // extract simply returns the A at the focus
    def extract[A](fa: FocusedGrid[A]): A = fa.grid(fa.focus._1)(fa.focus._2)
}
```

`extract` is the simplest operation and simply returns the grid value at the focus.

Looking at the type signature for `coflatten` you can see that it does what we expect; creates a FocusedGrid of FocusedGrids. We iterate through each row and column using `mapWithIndex` so that we can set the appropriate focus at each point. Note that the grid itself will not be duplicated in memory for each Vector, just a reference will be added. What is different at each row and column is the focus. Here's an example of a coflattened FocusedGrid.

```scala
FocusedGrid((0,0), Vector(Vector(5,3,0),Vector(3,1,0),Vector(0,0,0))).coflatten

FocusedGrid(
  (0, 0),
  Vector(
    Vector(
      FocusedGrid((0, 0), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((0, 1), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((0, 2), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0)))
    ),
    Vector(
      FocusedGrid((1, 0), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((1, 1), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((1, 2), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0)))
    ),
    Vector(
      FocusedGrid((2, 0), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((2, 1), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0))),
      FocusedGrid((2, 2), Vector(Vector(5, 3, 0), Vector(3, 1, 0), Vector(0, 0, 0)))
    )
  )
)
```

Once `coflatten` is available, the implementation of `coflatMap` follows by simply executing `coflatten` then `map`. Notice how this is the reverse of Monad's flatmap, which maps first and then flattens.

Now that FocusedGrid is a Comonad, what can we do with it? Note the function signature for `f` is `FocusedGrid[A] => B`. That means we can write a function that looks at the whole grid and lets do a calculation _from the point of view of the focus_ and create a single value of type `B`, which will be the new value of the final grid at that position.

The full implementation can be found here: [FocusedGrid.scala](https://github.com/justinhj/comonad/blob/blog-final-2/src/main/scala/org/justinhj/FocusedGrid.scala)

### Image smoothing

We can map image data directly to our FocusedGrid data type, and then use it to do image processing. A simple example is a box filter, which can be used to smooth out noise in images. In this implementation, which you can find in the file [ImageProcessor.scala](https://github.com/justinhj/comonad/blob/blog-final-2/src/main/scala/org/justinhj/ImageProcessor.scala), we will load an image file, copy the image data to a FocusedGrid, and then write the filter using the function signature `FocusedGrid[(Int,Int,Int) => (Int,Int,Int)`. Note that we represent image pixels as a tuple containing the red, green and blue components.

Here's the implementation of boxfilter. You pass in the width of the filter and it will then average the pixels for a square of the provide width (and height) and set each pixel to that average. The function `localSum` handles the summing the values found around the current focus, and then we create the new pixel by dividing to get the mean.

```scala
  def boxFilter(width: Int): FocusedGrid[(Int, Int, Int)] => (Int, Int, Int) = { fg =>
    val widthSqr = width * width
    val sum = localSum(fg, (255, 255, 255), width)
    ((sum._1 / widthSqr).toInt, (sum._2 / widthSqr).toInt, (sum._3 / widthSqr).toInt)
  }
```

Here is the original image and some smoothed examples at various box filter sizes:

![Original](/../images/girl.png "Original")

![Filter size 5](/../images/girlsmoothed5.png "Filter size 5")

![Filter size 15](/../images/girlsmoothed15.png "Filter size 15")

We can do any image transformation that requires access to the whole image to make some per-pixel change. Here's another example to mirror the image along the vertical axis.

```scala
  def mirrorHorizontal(fg: FocusedGrid[(Int, Int, Int)]): (Int, Int, Int) = {
    val mirrorX = (fg.grid(0).size - 1) - fg.focus._2
    fg.grid(fg.focus._1)(mirrorX)
  }
```

One of the benefits of functional programming is composability. We can sequence coflatMaps and maps together to generate new images. For example we would smooth and flip an image using `focusedGrid.coflatMap(boxFilter(9)).coflatMap(mirrorHorizontal)`, which gives the following image.

![Sequence](/../images/processedgirl.png "Sequence")

## Comonads for (Conway's) Life

Code for this section can be found here: [Conway.scala](https://github.com/justinhj/comonad/blob/blog-final-2/src/main/scala/org/justinhj/Conway.scala) 

<iframe width="560" height="315" src="https://www.youtube.com/embed/8UxwupNI4As" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

With a couple of small changes our image processing algorithm can be put to work to simulate the zero player game Conway's Life. See the [Wiki for Conway's Life](http://www.conwaylife.com/wiki/Main_Page) for more details. For a TL;DR the game involves a starting grid of cells which are alive (0) or dead (1). At each step we count the neighbours of each cell to see if it will be alive or dead in the next generation.

In order to animate the game in presentable manner in a regular terminal we can use a combination of unicode characters, ansi control commands and the Cats Show typeclass.

```scala
  implicit def focusedGridShow[A : Show] = new Show[FocusedGrid[A]] {
    def show(fg: FocusedGrid[A]): String = {
      fg.grid.map{
        row => row.iterator.map(_.show).mkString("")
      }.mkString("\n")
    }
  }
```

We need a simple function to convert the 0's and 1's of our life simulation with more attractive characters. By using `map` to apply the `prettify` then showing the grid we get a more pleasing representation than the zeros and ones.

```scala
 def prettify(i : Int) : Char = {
    i match {
      case 1 => 0x2593.toChar
      case 0 => 0x2591.toChar
    }
  }
  
FocusedGrid((0,0), Vector(Vector(1,1,1),Vector(1,1,0),Vector(0,0,0))).map(prettify).show 
▓▓▓
▓▓░
░░░
```

Note that code for life has a slightly different implementation of `localSum` which does not include the current focus point, we only want to know about the neighbours. Apart from that the code is very similar to the image processing example, since if we use 0 for dead and 1 for living, we can count living neighbours using `localSum`.

With everything in place we can implement the core of the game of life algorithm with just a few lines of code.

```scala
  def conwayStep(fg: FocusedGrid[Int]) : Int = {
    val liveNeighbours = localSum(fg)
    val live = getAt(fg, fg.focus)

    if(live == 1) {
      if(liveNeighbours >= 2 && liveNeighbours <=3) 1 else 0
    }
    else {
      if(liveNeighbours == 3) 1 else 0 
    }
  }
```

Note that the function `getAt` here is written to handle wrapping around the edges of the grid.

## Summary

In this post we've seen how monads and comonads are related, what the operations and laws of comonads are, and how they can be used to make useful, composable programs.

## References

Bartosz Milewski has this great series of posts "Categories for Programmers"
[https://bartoszmilewski.com/2017/01/02/comonads/](https://bartoszmilewski.com/2017/01/02/comonads/)

I came across this post by Eli Jordan when I'd almost finished writing this one and saw that he already covered a lot of the same ground; especially interesting is his use of Store which is the Comonad version of the State monad
[https://eli-jordan.github.io/2018/02/16/life-is-a-comonad/](https://eli-jordan.github.io/2018/02/16/life-is-a-comonad/)

Read about Comonads in the Cats API documentation
[https://typelevel.org/cats/api/cats/Comonad.html](https://typelevel.org/cats/api/cats/Comonad.html)

From 2015, Red Book Runar has a very detailed introduction to Comonads and their laws
[http://blog.higher-order.com/blog/2015/06/23/a-scala-comonad-tutorial/](http://blog.higher-order.com/blog/2015/06/23/a-scala-comonad-tutorial/)

Otfried Cheong has a great intro to image processing with Scala, utilizing the standard Java library
[http://otfried.org/scala/image.html](http://otfried.org/scala/image.html)

