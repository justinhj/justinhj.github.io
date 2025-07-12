---
layout: post
title:  "Using 47 Degree's Fetch library with ZIO"
tags: [scala, functional-programming, zio, hacker-news-api, 47-degs, fetch, popular]
---

This post has accompanying source code on Github:

- [https://github.com/justinhj/hnfetch/tree/zio-cats-effect](https://github.com/justinhj/hnfetch/tree/zio-cats-effect)
_Updated to latest ZIO etc: February 23 2020_

This post is an update to an ongoing series. See previous post here:

- [Hacker News API part 5](http://justinhj.github.io/2019/04/07/hacker-news-api-5.html)

## Fetch 1.0

47 Degrees create and maintain a useful library called Fetch, "A library for Simple & Efficient data access in Scala and Scala.js", which I've written about before, and recently reached version 1.0. You can check the full releases notes here:

- [https://github.com/47deg/fetch/releases/tag/v1.0.0](https://github.com/47deg/fetch/releases/tag/v1.0.0)

There are a few interesting changes in this release but most notable is the move to using Cats Effect. Previously, Fetch operated under the hood using `FetchMonadError`, a monadic type which you can implement in order to manage how your Fetch is interpreted at runtime. Twitter Futures, vanilla Scala Future's and Monix Task were supported.

As functional programming libraries start to standardise on a common API for effects, it makes it possible for library authors to implement their code in terms of a generic effect type, and then for the user, who may also be attached to a particular library, to provide their runtime and effect of choice.

Another interesting change which I haven't checked out yet, but is something I felt lacking from the pre-1.0 library was the ability to fetch potentially missing items. Rather than get an error if an item does not exist you can specify that it is optional.

Still present are the former features such as logging and caching, though oddly the ability to run a fetch with a cache and a log at the same time has been removed.

## Conversion to use Cats Effect

Step one of upgrading my code (a simple Hacker News API client) to use Fetch 1.0 was to update the DataSources that specify what things can be fetched and how.

```scala

  object HNItemSource extends Data[HNItemID, HNItem] {
    override def name = "item"

    def source[F[_]: ConcurrentEffect] = new DataSource[F, HNItemID, HNItem] {

      override def data = HNItemSource

      override def CF = ConcurrentEffect[F]

      override def fetch(id: HNItemID): F[Option[HNItem]] =
        CF.delay(HNFetch.getItemSync(id).toOption)
    }
  }

  def getItem[F[_]: ConcurrentEffect](id: HNItemID): Fetch[F, HNItem] = Fetch(id, HNItemSource.source)
```

The interesting changes from the original code are that we are passing in a higher kinded type F which must implement ConcurrentEffect from Cats. We also have a new type Data which wraps the DataSource's familiar from the previous version.

Now the file [HNDataSources.scala](https://github.com/justinhj/hnfetch/blob/zio-cats-effect/src/main/scala/justinhj/hnfetch/HNDataSources.scala) is updated to use generic effects we can implement the program using Zio, Cats Effect and any other compatible effect library.

In [FrontPageWithFetchCats.scala](https://github.com/justinhj/hnfetch/blob/zio-cats-effect/src/main/scala/examples/FrontPageWithFetchCats.scala) I've ported the previous version which used Monix Task to use Cats Effect. This process was straightforward because of the similarities between Monix and Cats.

## Using ZIO

Making the conversion to ZIO is a similar process except in the process I also modified the program to use Zio's new environment. This enables me to use Console replace all the println and readline code, and used ZIO's API to make the code a bit clearer than the original. If I wasn't sharing the code between Cats and Zio it would be better to add things like the Http retrieval and Json parsing as environments, so that they can be swapped out for testing performance of different libraries and for testing purposes.

```scala
    val cache = InMemoryCache.from[Task, HNItemID, HNItem]()

    val program = (for(
      items <- ZIO.absolve(getTopItems().mapError(_.getMessage));
      _ <- showPagesLoop(items, cache)
    ) yield ()).foldM(err => printError(err.toString), _ => ZIO.succeed(()))

    runtime.unsafeRun(program)
```

Since `getTopItems` handles errors using `Either[String, A]` I use a couple of ZIO's functions to map that to `ZIO[Env, String, A]`. 

We are now using, on the surface, ZIO's runtime and types, to call into Fetch and have it do work for us even though there is no explicit support for Scalaz in general, and ZIO in particular, in the Fetch library. Quite magical! All we need to make this work is some implicit conversion that lets ZIO take care of converting our ZIO structures to and and from Cats Effect ones:

[FrontPageWithFetchZio.scala](https://github.com/justinhj/hnfetch/blob/zio-cats-effect/src/main/scala/examples/FrontPageWithFetchZio.scala)
```scala
import scalaz.zio.interop.catz._
import scalaz.zio.interop.catz.implicits._
```

You can read about this in ZIO's documentation here: [ZIO Cats Effect interop](https://scalaz.github.io/scalaz-zio/interop/catseffect.html)

## Combinators - sequence and traverse

As discussed in the Fetch documentation you can use the combinators `traverse` and `sequence` to combine fetch's together. In the Cats Effect version we can fetch many items at once by constructing each invidual fetch (which has type `Fetch[F, A`) and adding them to a list. We then need to convert `List[Fetch[F, A]` to `Fetch[F, List[A]]`. This is done as follows:

```scala
  val pageOfItems = hNItemIDList.slice(startPage * numItemsPerPage, startPage * numItemsPerPage + numItemsPerPage)
  val fetchItems: Fetch[IO, List[HNItem]] = pageOfItems.traverse(getItem[IO])

  Fetch.runCache[IO](fetchItems, cache)
```

Now although I can run simple fetch's using ZIO interop without having to do much work, it's not as easy to use traverse with Scalaz and ZIO. I did spend some time trying but it appears that the reason this works in my Cats Effect code is that fetch itself implements a Monad for Fetch and that Monad is implemented in terms of Cats. In order to use the combinators without Cats you need to either reimplement the Fetch Monad, or at least enough operations to support traverse (applicative and pure), and then it will be fine.

Rather than go to those lengths, for the purposes of just making this work I implemented a helper function in the DataSources file, which uses Cats and returns the appropriate data structure which can then be used by ZIO when the Fetch executes.

```scala
  def getMultipleItems[F[_] : ConcurrentEffect](ids : List[HNItemID], cache: DataCache[F])
                                               (implicit cs: ContextShift[F], timer: Timer[F]) = {
 val fetchItems: Fetch[F, List[HNItem]] = ids.traverse(getItem[F])

 Fetch.runCache[F](fetchItems, cache)
}
```

## Conclusion

The experience of porting code to use Cats Effect and ZIO with a library that uses an effect type as its API was quite straightforward, and I find this style promising for the future, particularly as effects get more features and hopefully more standardised. It can get interesting to mentally juggle which typeclasses and data types you are using at any particular part of the program. 

Thanks for reading!

Copyright (C) 2019 Justin-Heyes-Jones - All Rights Reserved
