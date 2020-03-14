---
layout: post
title:  "Hacker News API Part 4"
date:   2018-05-05 00:00:00 -0000
tags: [scala, functional-programming, hacker-news-api, fetch, 47-degs, typelevel, monix]
---

# Hacker News API Part 4  - Fun with Monix

Previous related posts: 
* [Hacker News API part 3](/2017/10/11/hacker-news-api-3.html)
* [Hacker News API part 2](/2017/07/30/hacker-news-api-2.html)
* [Hacker News API part 1](/2017/07/26/hacker-news-api-1.html)

Code referred to here can be found on Github 

- [hnfetch](https://github.com/justinhj/hnfetch)

If you didn't read the previous 3 posts about this little learning project (or as my son calls it writing the same boring program over and over), then don't worry because this will be self-contained and an introduction to the Monix library and a couple of fun things you can do with it.

As a Typelevel project Monix has great documentation and high development standards, see [here](https://monix.io) for more. The library was created by Alexandru Nedelcu and I highly recommend his entertaining and informative video presentation on the monix.io site.

In this post, we go back to part 2 of this series where I made an interactive command line client for viewing Hacker News stories. The first step is to get the list of top stories which is a simple list of story IDs. I used the [Fetch](http://47deg.github.io/fetch/docs#introduction-0) library from 47Degs to manage the retrieval of each story. Fetch manages the number of concurrent operations you do as well as handling caching. Under the hood Fetch is implemented using Cats [Free](https://typelevel.org/cats/datatypes/freemonad.html)

As you can see in the image there is a bit of diagnostic information in the background showing which threads the task is running on. This helps when debugging and configuring multi-threaded code.

![HNFetch](/../images/hnfetch.png)

As is often the case when looking at old code, maybe especially your own, you see things that make you sad. In this case, there are two sad things relating to functional programming and both of them will be fixed by the end of the post. The first sad thing is the use of Future and the second is the lack of _composablity_.

# The Future of Future

Scala's Future is a simple to use abstraction that lets you work with values that typically will take some time to compute. Common examples are fetching some data from a database or calling a remote service endpoint. In imperative programming, you would probably have the DB operation start on another thread and ask that thread to 'callback' to you when it's done. Scala's Future provides an ExecutionContext, essentially the instructions and configuration for how to run the Future code. Every Future must have an implicit ExecutionContext in scope, although you can pass one explicitly if you like. 

Once created a Future will usually execute immediately (it could be that it is asked to run on a thread pool that is busy and it will have to wait for a place in the queue.) Once executed it will complete by setting its value (or return an error if it fails). As a user of the Future we must eventually wait for it somehow, for example using the blocking call Await.result. This will wait for the Future to get its value set by a successful operation, or for the Future's error to be set, or finally it the Await operation itself could timeout.

Unfortunately, this eager evaluation of Future means that it is not referentially transparent. As functional programmers we want referential transparency because it makes programs easier to reason about. I found a very nice and succinct demonstration of this problem in a [Reddit comment](https://www.reddit.com/r/scala/comments/3zofjl/why_is_future_totally_unusable/?st=jguak5en&sh=8064a725) by Rob Norris (@tpolecat): 

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

In this example, we are running some side-effecting code in the Future (generating a random number mutates the Random object by updating its seed). The result of running f1 is:

`Future[(Int, Int)] = Future(Success((-1155484576,-1155484576)))`

Whilst f2 gives:

`Future[(Int, Int)] = Future(Success((-1155484576,-723955400)))`

For referential transparency, we can take any function and its arguments and replace it with the result. 

```
val x = something
(x, x)
```

should be the same as 

```
(something, something)
```

That is broken in the Future example above because x in the first example is eagerly evaluated on creation, and the random value is fixed (memoized) for as long as the Future exists. 

# Monix Task

Monix provides Task that we can use instead of Future. It adds a lot of features, most notably for our purposes is that it allows us to lazily evaluate our code. In fact, that is the default. In the Future example above we can simply replace Future with Task and we will find that referential transparency is restored:

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

Besides that Monix Tasks have a lot of features and improvements over the Scala Future. For example, Monix Tasks do not require an execution context for their create, map and flatMap operations. In fact, you don't need to provide one until you actually run something, which can be in one nicely contained place in your program 'at the end of the world'. The Monix Scheduler has an ExecutionContext and includes features such as running a Task after a delay or repeatedly. 

Another advantage of the Task object being so full featured is that we can wrap all the parts of our program using it and then compose them neatly at will. Due to the way flatMap is defined you cannot use different effect types. That means you end up with ugly for comprehensions where most of the flatMaps are operating on a certain effect such as Future or Option, but there are outliers that have to be cast in-line. If we write our program in terms of simple Task's we can compose them without having to worry about the effect type not lining up. 

# Changes to the HNFetch code

In order to convert my Hacker News fetch command-line code from an essentially imperative Scala program to one that is composed of Task's took a few simple steps:

## Library Imports 

I updated the Fetch library version and brought in the fetch-monix integration which allows you to use Monix Task when running Fetch operations.

```
val fetchVersion = "0.7.2"

libraryDependencies ++= Seq(
  "com.47deg" %% "fetch" % fetchVersion,
  "com.47deg" %% "fetch-monix" % fetchVersion)
```

Fetch will bring in the Monix library but I also wanted the `monix-reactive` module for something we'll see later in the post, so I brought that in manually.

`"io.monix" %% "monix-reactive" % "3.0.0-M3"`

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

In this code most of the changes were removing Future from functions that can actually be simply synchronous. We'll later let Monix Task handle scheduling them on threads. The one exception is the function `getTopItems` which will we call as a single Task (the other http gets are made by Fetch itself and will be wrapped by Tasks later). So in refactoring, I've created a Sync (blocking) and a regular (Task wrapped) version of the supported Hacker News API.

```
  def getTopItems(): Task[Either[String, HNItemIDList]] = Task.eval {
    hnRequest[HNItemIDList](getTopItemsURL)
  }
```

## [FrontpageWithFetch.scala](https://github.com/justinhj/hnfetch/blob/master/src/main/scala/examples/FrontPageWithFetch.scala)

Note that all the side effects in the program now occur in Task objects. We can _compose_ the program together from these small pieces using all the functional programming tools we have available. This is the main loop, asking for user input and showing the next news items:

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

# So?

With a few changes, we've turned a simple ugly program that used old-fashioned Futures and was not at all composable into a much more useful program made of small composable parts. If you don't believe me then check out the old code [here](https://github.com/justinhj/hnfetch/blob/blogpost2/src/main/scala/examples/FrontPageWithFetch.scala)

Not only is the new code easier to read, we now have the parts that make it up available to easily make new programs.

# A small demo of Monix Reactive

I'm just getting started learning about what the Monix library, but I spent a few minutes playing around in the [Ammonite](http://ammonite.io/) REPL and had a lot of fun. For example, Hacker News has a MaxItem API, which tells you the ID of the last posted item (it increase monotonically). So I used the Monix Observer (part of the reactive module) to generate a tick every 30 seconds at which point you can execute a Task. These few lines of code will check Hacker News every 30 seconds and print the latest comment:

![Live comments](/../images/livecomments.png)

```
import monix.eval.Task
import scala.concurrent.duration._
import scala.concurrent.Await
import justinhj.hnfetch.HNFetch._
import monix.execution.Scheduler.Implicits.global
import monix.reactive._

def latestComment = getMaxItem.flatMap {
    case Right(itemId) =>
      getItem(itemId).flatMap {
        case Right(item) if item.`type` == "comment" =>
          Task(println(s""""${item.text}" - ${item.by}"""))
        case Right(item) =>
          Task.unit
        case Left(err) =>
          Task(println(s"error $err"))
      }
    case Left(err) =>
      Task(println(s"error $err"))
  } 

val s1 = Observable.interval(10 seconds).take(10)
val c1 = s1.mapTask(_ => latestComment).subscribe 

// Starts showing messages every 30 seconds (ten times)

// When you get bored...

c1.cancel
```

I leave you with the first comment that came up

`"Human kind will be gone in 1000 years? That’s a pessimistic view. I hope not!" - camdenreslink`

Copyright (C) 2018 Justin-Heyes-Jones - All Rights Reserved
