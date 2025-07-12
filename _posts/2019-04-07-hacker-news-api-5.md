---
layout: post
title:  "Hacker News API Part 5"
tags: [scala, functional-programming, zio, hacker-news-api, popular]
---

Updated June 29th 2019 to work with latest ZIO version (1.0.0-RC8-12)

This post has accompanying source code on Github:

- [https://github.com/justinhj/ziohnapi/](https://github.com/justinhj/ziohnapi/tree/blog-2019-04-07-b)

Hacker News is a news aggregation site which provides a simple API over http, for which the documentation can be found [here](https://github.com/HackerNews/API). Over several blog posts I have been writing programs that interact with the API as a way of exploring new techniques in Scala pure functional programming.

This post is the fifth in a series. Here's what came before:

1. Using Future[Either, E] with a http library and uPickle [Hacker News API part 1](/2017/07/26/hacker-news-api-1.html)
2. Using the Fetch library from 47 degrees [Hacker News API part 2](/2017/07/30/hacker-news-api-2.html)
3. Added a web front end using U-Dash, converted to ScalaJS and visualization of the Fetch operations with RefTree [Hacker News API part 3](/2017/10/11/hacker-news-api-3.html)
4. Get rid of Future and structure the program better using Monix's effect type, Task. [Hacker News API part 4](/2018/05/05/hacker-news-api-4.html)

A few months ago I attempted to update the code using two other techniques. The first was tagless final style (see [https://softwaremill.com/free-tagless-compared-how-not-to-commit-to-monad-too-early/](https://softwaremill.com/free-tagless-compared-how-not-to-commit-to-monad-too-early/)) and the second was using a monad transformer library approach [https://typelevel.org/cats-mtl/](https://typelevel.org/cats-mtl/)

What these techniques have in common is they allow us to defer the specific Monad type used in our code until later, allowing more flexibility and the ability to, for example, replace an asynchronous Task effect with a simpler Monad such as Id. This would enable us to write test suites that run faster. In addition it allows to swap out implementations of things like logging. Something like dependency injection at the higher kinded type level.

While I was able to get my Hacker News API working with both these techniques, I never really got the code to a state where I wanted to share it with the world, or would be prepared to push it onto a team as an example of good style, so having seen this John de Goes talk [The Death Of Final Tagless ](https://skillsmatter.com/skillscasts/13247-scala-matters) and his follow up [Beautiful, Simple, Testable Functional Effects for Scala](http://degoes.net/articles/zio-environment), I decided it was time to start investigating ZIO.

Like Monix, ZIO is a library that provides a full suite of tools for writing asynchronous and concurrent programs. You can see the full documentation here: [Zio documentation](https://scalaz.github.io/scalaz-zio/)

The example code consists of three example programs. The first is based on my previous posts and simply retrieves and displays the current stories a page at a time.

## Showing front page stories

[ShowStories.scala](https://github.com/justinhj/ziohnapi/blob/blog-2019-04-07-b/src/main/scala/examples/ShowStories.scala) is one of the examples include that simply gets the top stories (a list of story IDs ranked by their position on the Hacker News page) and then displays them in the console...

```scala
    val runtime = new LiveRuntime {}

    val program = (for (
      s <- httpclient.get(getTopItemsURL);
      items <- parseTopItemsResponse(s);
      _ <- showPagesLoop(items)
    ) yield ()).foldM(
      err =>
        putStrLn(s"Program threw exception. ${err.getMessage}"),
      succ => ZIO.succeed(())
    )

    runtime.unsafeRunSync(program)
```

The showPagesLoop asks the user for a page number and continues looping until the user enters something that is not a number:

```scala
  def showPagesLoop(topItems: HNItemIDList) : ZIO[Env, Throwable, Unit] = {

    val itemsPerPage = 5

    getUserPage.flatMap {
      case Some(pageNumber) =>
        for(
          _ <- putStrLn(s"Page $pageNumber");
          items <- fetchPage(pageNumber, itemsPerPage, topItems);
          _ <- printPageItems(pageNumber, itemsPerPage, items);
          _ <- showPagesLoop(topItems)
        ) yield ()
      case None =>
        putStrLn("Have a nice day!")
    }
  }
```

## Modules and the environment

The programs are built from modules that make up the R part of ZIO[R,E,A]. I'm using the built in ones Blocking and Console, along with my own HttpClient that takes of retrieving data from a url as a string.

An Environment for the runtime is an aggregation of the modules that make up your whole program:

`type Environment = Clock with Console with System with Random with Blocking with HttpClient`

Blocking is module that allows blocking operations to use a special threadpool, so that blocking calls don't deplete threads from your main thread pool. Effects can be made to run on the blocking pool just by wrapping them as follows:

[HttpClient.scala](https://github.com/justinhj/ziohnapi/blob/blog-2019-04-07-b/src/main/scala/org/justinhj/httpclient/HttpClient.scala)

```scala
  blocking(ZIO.effect(requestSync(url)))
```

## Testing

The nice thing about HttpClient being a module is that I can test my code without a web connection, or without hitting the real Hacker News by swapping the real implementation with a test one. You can see that in action in the test suite:

[HNApiTest.scala](https://github.com/justinhj/ziohnapi/blob/blog-2019-04-07-b/src/test/scala/org/justinhj/HNApiTest.scala) - sample test suite
```scala
  // The test http runtime
  trait HttpClientTest extends HttpClient {

    val sampleTopStories = Test data omitted
    val sampleItem = Test data omitted

    val httpClient: Service[Any with HttpClient with Blocking] = new Service[Any with HttpClient with Blocking] {

      def requestSync(url: String) : String = {
        if(url == HNApi.getTopItemsURL) sampleTopStories
        else if(url == HNApi.getItemURL(11498534)) sampleItem
        else throw new Exception(s"$url not found in http mock client")
      }

      final def get(url: String) : Task[String] = {
        ZIO.effect(requestSync(url))
      }
    }
  }

```

This concept of swapping out modules can be useful for testing different databases, different JSON parsers and so on.

## Fibers

ZIO allows a large number of concurrent operations by using an implementation of green threads called Fibers. The API is straightforward. For example in this function that retrieves an item and them recursively retrieves its 'kids' (for example kids of a comment are nested comments, kids of a news story are the top level comments on that story) and we use the function `foreachParN(8)` to split the jobs across up to 8 individual fibers. This gives you control over the amount of active fibers in each part of your application.

[HNApi.scala](https://github.com/justinhj/ziohnapi/blob/2a7e5d634813afd43f6c9e306807c69186138c28/src/main/scala/org/justinhj/hnapi/HNApi.scala#L126)

```scala
  def getItemAndKidsList(parentId: Int) : ZIO[Env, Throwable, List[HNItem]] =
    for(
      itemResponse <- httpclient.get(getItemURL(parentId));
      item <- parseItemResponse(itemResponse);
      kids <- ZIO.foreachParN(8)(item.kids){id => getItemAndKidsList(id)}
    ) yield kids.flatten :+ item
```

This function is used in the code below to show all the comments for a given news story (by its ID):

[ShowStoryComments.scala](https://github.com/justinhj/ziohnapi/blob/blog-2019-04-07-b/src/main/scala/examples/ShowStoryComments.scala)

```scala
    val program = (for (
      itemId <- getItemId;
      itemsAndKids <- getItemAndKids(itemId);
      _ <- showComments(itemId, itemsAndKids)
    ) yield ()).foldM(
      err =>
        putStrLn(s"Program threw exception. $err"),
      succ => ZIO.succeed(())
	  )
```

## Scheduling

Another feature of ZIO is the scheduler data type. Again, the API is composed of simple operations that you can compose together to make more complex overall behaviours. In this simple example we grab the latest story or comment submitted to Hacker News every 10 seconds until the user quits.

[LastItem.scala](https://github.com/justinhj/ziohnapi/blob/blog-2019-04-07-b/src/main/scala/examples/LastItem.scala)

```scala
    val showLastItem = for (
      maxItemResponse <- httpclient.get(getMaxItemURL);
      maxItem <- parseMaxItemResponse(maxItemResponse);
      itemResponse <- httpclient.get(getItemURL(maxItem));
      item <- parseItemResponse(itemResponse);
      _ <- showComment(item)
    ) yield ()

    val program = showLastItem.repeat(Schedule.spaced(10.seconds))

    runtime.unsafeRunSync(program)
```

## Final words

ZIO is easy to use and very powerful, a great combination. Even though the applications are built using solid pure fp concepts such as the Reader and State monads, these are beneath the surface of the API, and the user can concentrate on building the application.

I am just getting started with ZIO and any feedback on my example program and post, good or bad, is welcome. You can contact me via Twitter or Email at the top of the page, or open a Github issue.

Thanks for getting to the end!

## Post script

Thanks for all the great feedback on this article! I have now changed all occurences of the word Fibre with Fiber. I accidentally used the British spelling of the word which is inconsistent with the spelling in Zio itself.

Copyright (C) 2019 Justin-Heyes-Jones - All Rights Reserved
