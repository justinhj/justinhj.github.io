---
layout: post
title:  "Hacker News API Part 2"
date:   2017-07-30 00:00:00 -0000
tags: [scala, functional-programming, hacker-news-api, fetch, typelevel, 47-degs]
---

Previous post: [Hacker News API part 1](/2017/07/26/hacker-news-api-1.html)

Github project related to this post [hnfetch](https://github.com/justinhj/hnfetch)

**Note**: I've updated this project a lot since this post but you can get the version from this post from this tagged [release](https://github.com/justinhj/hnfetch/tree/blogpost2).

In the last post I demonstrated building a program to fetch data from the Hacker News API using a combination of libraries including scalaj-http and uPickle. This time I will demonstrate a wrapper around the core functionality using the [Fetch](http://47deg.github.io/fetch/docs) library by the cool folk at 47 Degrees.

Fetch is based on the Facebook's Haskell library [Haxl](https://code.facebook.com/posts/302060973291128/open-sourcing-haxl-a-library-for-haskell/) and is designed to reduce the amount of complexity around managing calls to data sources such as caches, databases and web api's. In this article I will show how to turn my simple http calls to the Hacker News [API](https://github.com/HackerNews/API) into Fetch friendly data sources. That will then enable us to take advantage of automatic caching of stories and users, management of how many concurrent calls to make as well as giving us a nice purely functional interface to the data which uses Free Monads.

Since their documentation already contains a very good tutorial and guide to all the features, I won't repeat that here and encourage you to read that instead.

Fetch uses functional programming library Cats, so let's bring that into the project as well as Fetch itself:

{% highlight scala %}

libraryDependencies ++= Seq(
  "org.typelevel" %% "cats" % "0.9.0",
  "com.47deg" %% "fetch" % "0.6.2")

{% endhighlight %}

The next step in converting the Hacker News api code to Fetch is to create datasource for the user and story types.

As you can see in the Fetch documentation (and source) a datasource just has to say how to get one of a thing, multiple things, and some behaviour configuration: [DataSource](https://github.com/47deg/fetch/blob/master/shared/src/main/scala/datasource.scala)

Here's the data sources for Hacker News items and stories. 

{% highlight scala %}

object HNDataSources {

  // Some constants to control the behaviour of Fetch executions
  // These could be moved to a config file in a real applications

  val fetchTimeout : Duration = 10 seconds // max time to wait for a single fetch
  val batchSize = Some(8) // max concurrent requests of each data source
  val executionType : ExecutionType = Sequential // whether to do batches concurrently or sequentially

  import cats.data.NonEmptyList

  implicit object HNUserSource extends DataSource[HNUserID, HNUser]{
    override def name = "user"

    override def maxBatchSize = batchSize
    override def batchExecution = executionType

    override def fetchOne(id: HNUserID): Query[Option[HNUser]] = {

      Query.async({
        (ok, fail) =>
          HNFetch.getUser(id) onComplete {

            case Success(futSucc) => futSucc match {
              case Right(item) =>
                println(s"GOT Item $id")
                ok(Some(item))
              case Left(err) =>
                ok(None)
            }

            case Failure(e) =>
              fail(e)
        }
      }, fetchTimeout)

    }

    // If the data source supports multiple queries (the HN API does not) you can implement it here
    // otherwise you can just tell it to use the single one using this built in function...
    override def fetchMany(ids: NonEmptyList[HNUserID]): Query[Map[HNUserID, HNUser]] = {
      batchingNotSupported(ids)
    }
  }

  implicit object HNItemSource extends DataSource[HNItemID, HNItem]{
    override def name = "item"

    override def maxBatchSize = batchSize
    override def batchExecution = executionType

    override def fetchOne(id: HNItemID): Query[Option[HNItem]] = {
      Query.async({
        (ok, fail) =>
          println(s"GET Item $id")
          HNFetch.getItem(id) onComplete {

            case Success(futSucc) => futSucc match {
              case Right(item) =>
                println(s"GOT Item $id")
                ok(Some(item))
              case Left(err) =>
                ok(None)
            }

            case Failure(e) =>
              fail(e)
          }
      }, fetchTimeout)

    // If the data source supports multiple queries (the HN API does not) you can implement it here
    // otherwise you can just tell it to use the single one using this built in function...
    override def fetchMany(ids: NonEmptyList[HNItemID]): Query[Map[HNItemID, HNItem]] = {
      batchingNotSupported(ids)
    }
  }

  def getUser(id: HNUserID): Fetch[HNUser] = Fetch(id)
  def getItem(id: HNItemID): Fetch[HNItem] = Fetch(id)

}

{% endhighlight %}

Some things to note:

* You also need to make smart constructors for each datasource to create `Fetch[T]`
* Each data source has a name to identify it. "item" and "story" in this case
* You can define how mant requests to make to each data source in batches, if the underlying DB or resource supports batching for example.

With that underway we can now utilize the Fetch library to grab our data in various ways. The example program [FrontPageWithFetch](https://github.com/justinhj/hnfetch/blob/master/src/main/scala/examples/FrontPageWithFetch.scala) demonstrates the runF command `fetchItems.runF[Future](cache.get)` which returns both the Fetch result and a FetchEnv. The FetchEnv includes a detailed history of the fetch operaion as well as a cache that we can pass into the next call and avoid retrieving duplicate items. Check the Fetch documentation for how to implemnent your own cache should you need specific behaviour. 

Here's a little video of the interactive front page terminal app showing how repeated requests to the same page do not request them from the API... 

<iframe width="560" height="315" src="https://www.youtube.com/embed/4BxsPPX0nxs?rel=0&amp;showinfo=0" frameborder="0" allowfullscreen></iframe>

Fetch's big idea is to hide complexity such as caching, rate limiting and other complexities from client code, another big advantage of such a functional approach is that you can compose queries. In this example (not in the github repo) I demonstrate grabbing a user and his submitted items in a for comprehension. Note that the call to getUser and getItems compose nicely into Fetch operations and are then executed with runA to get the result.

{% highlight scala %}

  def monadicFetch() = {

    println(s"Main thread id ${Thread.currentThread().getId}")

    val seqFetch = for (
      user <- getUser("justinhj");
      //item <- getItem(user.submitted(0)) // get one item
      //items <- (user.submitted.map(getItem(_))).sequence // get multiple as a sequence
      _ =  println(s"user has ${user.submitted.size} submitted items");
      items <- user.submitted.take(10).traverse(getItem) // get multiple using traverse
    ) yield (user, items)

    val (user, items) = Await.result(seqFetch.runA[Future], Duration.Inf)
    println(s"""I got user ${user.id} and his submissions "${items.size}"""")
    items.filter(i => i.`type` == "story").foreach{i => println(s"${i.id} : ${i.`type`}")}
    
  }
  
{% endhighlight %}

This has been a short and sweet introduction to Fetch. It seems like a solid library with a lot of use cases, and a good example of Free Monad's in the wild.

Postscript: Thanks to a suggestion from @peterneyens I've update the async datasources to use onComplete rather than map/recover 

