---
layout: post
title:  "Hacker News API Part 4 - Composing programs with Monix Tasks"
date:   2018-05-05 00:00:00 -0000
tags:
- scala
- functional programming
- Hacker News
- Hacker News API
- fetch
- typelevel
- monix
---

Previous related posts: 
* [Hacker News API part 3](/2017/10/11/hacker-news-api-3.html)
* [Hacker News API part 2](/2017/07/30/hacker-news-api-2.html)
* [Hacker News API part 1](/2017/07/26/hacker-news-api-1.html)

Code referred to here can be found on Github 

- [hnfetch](https://github.com/justinhj/hnfetch)

Warning this is a WIP - stay tuned for a better revision

# Hacker News Fetch - Composing programs from Monix Tasks

If you didn't read the previous parts of this series you can do so following the links above, but this post is effectively self contained and is really about composing your programs from Monix tasks and why may want to do that. For more information Monix has fantastic documentation [here](https://monix.io/docs/3x/).

For this post we go back to part 2 of this series where I made an interactive command line client for viewing Hacker News stories. The first step is to get the list of top stories which is a simple list of story IDs. The I used the [Fetch](http://47deg.github.io/fetch/docs#introduction-0) library from 47Degs to manage the retrieval of each story. Fetch manages the number of concurrent operations you do as well as handling caching. Under the hood Fetch is implemented using Cats [Free](https://typelevel.org/cats/datatypes/freemonad.html)

In this post I'll replace all of the Scala Future's in the code with Monix Task. 

# IO Monad and Scala

Early in Haskell's history the Monad was proposed as a way to deal with things that have side effects and still deal with pure values. In the paper [Imperative Functional Programming](https://www.microsoft.com/en-us/research/publication/imperative-functional-programming/), Simon Peyton-Jones explains how and why to use Monads to compose IO effects. Some select quotes:

IO monads represent doing some IO and returning a value as "a way to reconcile being with doing".

"An expression in a functional language _denotes_ as value, while an I/O command should _perform_ an action"

When converting a Scala program from an imperative to a pure functional style with IO encapsulated in some structure, you might ask yourself this question:

"Does the monadic style force one, in effect, to write a functional facsimile of an imperative program?"

The answer according to the paper is no, because you are still able to use all the nice parts of functional program, but you can wield them to manipulate, sequence and compose IO objects. For the purposes of your functional code you can ignore that the things you are manipulating have external effects until the point where you run the program.

# Future has no Future

Scala's Future is a simple to use abstraction that lets you work values that typically will take some time to compute. Common examples are fetching some data from a database or networked service. In imperative programming you would probably have the DB operation start on another thread and ask that thread to 'callback' to you when it's done. A Future abstracts that from the user in a couple of ways. Firstly the scala.concurrent library provides an ExecutionContext, essentially the instructions and configuration for how to run the Future code. Every Future must have an implicit ExecutionContext in scope, although you can pass one explicitly if you like. 

Once created a Future will execute immediately (most likely, it could be that it is asked to run on a thread pool that is busy and it will have to wait for a place in the queue.) Once executed it will complete by setting its value (or return an error if it fails). 

Unfortunately this eager evaluation of Future means that it is not referentially transparent. As functional programmers we want referential transparency because it makes programs easier to reason about. I found a nice demonstration of this problem on Reddit in a [Reddit](https://www.reddit.com/r/scala/comments/3zofjl/why_is_future_totally_unusable/?st=jguak5en&sh=8064a725) by Rob Norris (@tpolecat): 

```
import scala.concurrent.future
import scala.util.Random
import scala.concurrent.ExecutionContext.Implicits.global

val f1 = { 
  val r = new Random(0L)
  val x = Future(r.nextInt)
  for { 
    a <- x
    b <- x
  } yield (a, b) 
}

// Same as f1, but I inlined `x`
val f2 = { 
  val r = new Random(0L)
  for { 
    a <- Future(r.nextInt)
    b <- Future(r.nextInt)
  } yield (a, b) 
}
```

In this example we are running some side effecting code in the Future (generating a random number mutates the Random object by updating its seed). The result of running f1 is:

`Future[(Int, Int)] = Future(Success((-1155484576,-1155484576)))`

Whilst f2 gives:

`Future[(Int, Int)] = Future(Success((-1155484576,-723955400)))`

For referential transparency we can take any function and its arguments and replace it with the result. That is broken here because x in the first example is eagerly evaluated on creation and the random value is fixed in its 'memory' for as long as the Future exists. 

# Monix Task

Monix is a great Scala library that provides a Task object that we can use instead of Future. It adds a lot of features, most notably for our purposes is that it allows us to lazily evaluate our code, in fact that is the default. In the Future example above we can simply replace Future with Task and we will find that referential transparency is restored:

```
import monix.
import scala.util.Random
import monix.execution.Scheduler.Implicits.global
 
val t1 = { 
  val r = new Random(0L)
  val x = Task(r.nextInt)
  for { 
    a <- x
    b <- x
  } yield (a, b) 
}

// Same as f1, but I inlined `x`
val t2 = { 
  val r = new Random(0L)
  for { 
    a <- Task(r.nextInt)
    b <- Task(r.nextInt)
  } yield (a, b) 
}
```

Now you'll find that both t1 and t2 return the same value `(-1155484576,-723955400)`

Besides that Monix Tasks have a lot of features and improvements over the Scala Future. Another thing is that Monix Tasks do not require an execution context for their map and flatMap operations. In fact you don't need to provide one until you actually run something, which can be in one nicely contained place in your program 'at the end of the world'. The Monix Scheduler has an ExecutionContext and includes features such as running a Task after a delay or repeatedly. 

Another advantage of the Task object being so full featured is that we can wrap all the parts of our program using it and then compose them neatly at will. Due to the way flatMap is defined you cannot use different effect types. That means you end up with ugly for comprehensions where most of the flatMaps are operating on a certain effect such as Future or Option, but there are outliers that have to be cast in-line. If we write our program in terms of simple Task's we can compose them without having to worry about the effect type not lining up. 

# Changes to the HNFetch code

In order to convert my Hacker News fetch comman-line code from an essentially imperative Scala program to one that is compose of Task's took a few simple steps:

## Library Imports 

I updated the Fetch library version and brought in the fetch-monix integration which allows you to use Monix Task when running Fetch operations.

```
val fetchVersion = "0.7.2"

libraryDependencies ++= Seq(
  "com.47deg" %% "fetch" % fetchVersion,
  "com.47deg" %% "fetch-monix" % fetchVersion)
```

Fetch documentation for working with Monix is [here](http://47deg.github.io/fetch/docs#concurrency-monads-7-monix-task-1). 

## [HNDataSources.scala](https://github.com/justinhj/hnfetch/blob/master/src/main/scala/justinhj/hnfetch/HNDataSources.scala)

This is not really related to the process of replacing Future with Task but a refactor to replace Query.async calls with Query.sync. This goes hand in hand with removing Future from other parts of the program. Since my http library is synchronous, and Fetch can handle synchronous functions, this change made sense. Note that this file no longer has any reference to Future or Monix Task which makes it more flexible. The caller should be able to specify the effect type. 

```

    override def fetchOne(id: HNUserID): Query[Option[HNUser]] = {

      Query.sync(HNFetch.getUser(id) match {
        case Right(a) => Some(a)
        case Left(_) => None
      })
    }
```

## [HNFetch.scala](https://github.com/justinhj/hnfetch/blob/master/src/main/scala/justinhj/hnfetch/HNFetch.scala)

In this code most of the changes were removing Future from functions that can actually be simply synchronous. We'll later let Monix Task handle scheduling them on threads. The one exception is the function geTopItems which will we call as a single Task (the other http gets are made by Fetch itself and will be wrapped by Tasks later)

```
  def getTopItems(): Task[Either[String, HNItemIDList]] = Task.eval {
    hnRequest[HNItemIDList](getTopItemsURL)
  }
```

## [FrontpageWithFetch.scala](https://github.com/justinhj/hnfetch/blob/master/src/main/scala/examples/FrontPageWithFetch.scala)

Note that all the side effects in the program now occur in Task objects. We can compose the program together from these small pieces using all the functional programming tools we have available. This is the main loop, asking for user input and showing the next news items:

```

  def showPagesLoop(topItems: HNItemIDList, cache: Option[DataSourceCache]): Task[Option[DataSourceCache]] =

  // Here we will show the page of items or exit if the user didn't enter a number
    getUserPage.flatMap {

      case Some(page) =>
        println(s"fetch page $page")

        for (
          fetchResult <- fetchPage(page, numItemsPerPage, topItems, cache);
          (env, items) = fetchResult;
          _ = println(s"${env.rounds.size} fetch rounds");
          _ <- printPageItems(page, numItemsPerPage, items);
          newCache <- showPagesLoop(topItems, Some(env.cache))
        ) yield newCache


      case None =>
        Task.now(cache)
    }
```

and the main loop:

```

  // Set a fixed size pool with a small number of threads so we can be nice to the Hacker News servers by
  // limiting the number of concurrent requests
  val scheduler = monix.execution.Scheduler.fixedPool("monix-pool", 4, true)

  def main(args : Array[String]) : Unit = {

    // Finally the main program consists of getting the list of top item IDs and then calling the loop ...

    val program = getTopItems().flatMap {
      case Right(items) =>
        showPagesLoop(items, None)
      case Left(err) =>
        printError(err)
    }

    val ran = program.runAsync(scheduler)
    Await.result(ran, Duration.Inf)

  }

}
```

# Conlusion

So what did I gain by doing this conversion? The main goal was to learn a bit more about the Monix library especially Task. A wider goal is to explore the idea of isolating side effects in Scala programs. Looking at the old program and the new program you can clearly see that the new one is easier to reason about and more composable and cleaner. 

One thing I did not get that I was expecting was better testability. If I wanted to mock my http library for example, to test the program offline or ignoring network errors, it's not clear that it is easy to do. Maybe that is more the domain of Free Monad and Tagless Final. 

----


Copyright (C) 2018 Justin-Heyes-Jones - All Rights Reserved
