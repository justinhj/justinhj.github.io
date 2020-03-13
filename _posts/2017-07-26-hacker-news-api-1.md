---
layout: post
title:  "Hacker News API Part 1"
date:   2017-07-26 23:00:00 -0000
tags: [scala, functional-programming, hacker-news-api]
---

Previous post: [Future with Timeout](/2017/07/16/future-with-timeout.html)

Github project related to this post [hnfetch](https://github.com/justinhj/hnfetch)

This is a quick post that will develop code to query [Hacker News](https://news.ycombinator.com/news) stories and users using the provided Firebase [API](https://github.com/HackerNews/API). Although you can access the API using a Firebase client library, I thought it would be fun to develop my own to revisit some of the error handling topics from previous posts and demonstrate a couple of common libraries in the Scala ecosystem.

We will only be concerned with queries, so all we need to pull data down from the API is a HTTP library. I'll use [ScalaJ-HTTP](https://github.com/scalaj/scalaj-http). This is a nice and simple library that is also thread safe, so although it doesn't offer an Asynchronous API, we can use Scala's concurrency library to make it behave like it is.

Since the data will come back as JSON we need to parse it into Scala data structures. In production projects I'd recommend a more full featured and performant library such as [Scala Jackson](https://github.com/FasterXML/jackson-module-scala), but a much easier to use library [uPickle](http://www.lihaoyi.com/upickle-pprint/upickle/)

Finally we'll include scalatest so we can write some tests as we go. I'll post a link to the working code at the end of the post but for now here are the required dependencies.

{% highlight scala %}

  "org.scalaj" %% "scalaj-http" % "2.3.0",
  "com.lihaoyi" %% "upickle" % "0.4.4",
  "org.typelevel" %% "cats" % "0.9.0",
  "org.ocpsoft.prettytime" % "prettytime" % "3.2.7.Final",
  "org.scalatest" %% "scalatest" % "3.0.1" % "test",
  "com.lihaoyi" % "ammonite" % "1.0.0" % "test" cross CrossVersion.full

{% endhighlight %}

I've also add lihaoyi's ammonite library, set up so that you run the job test:run in sbt and get an interactive repl to play with the api.

```
> test:run
[info] Running amm 
Welcome to the Ammonite Repl 1.0.0
(Scala 2.12.2 Java 1.8.0_60)
If you like Ammonite, please support our development at www.patreon.com/lihaoyi
@ import justinhj.hnfetch._ 
import justinhj.hnfetch._
@ val f1 = HNFetch.getUser("justinhj") 
f1: concurrent.Future[Either[String, HNFetch.HNUser]] = Future(<not completed>)
@ f1 
res2: concurrent.Future[Either[String, HNFetch.HNUser]] = Future(Success(Right(HNUser(justinhj,1249966944,1247, ... 
```

We'll build up a simple companion object HNFetch to do all the work and put it in the file `src/main/justin/hnfetch/HNFetch.scala`

When using scalaj-http we can use the built in Http object to do all out queries but it also is simple to override it with some custom options. Let's do that and change the user agent:

{% highlight scala %}

  object CustomHttp extends BaseHttp(
    proxyConfig = None,
    options = HttpConstants.defaultOptions,
    charset = HttpConstants.utf8,
    sendBufferSize = 4096,
    userAgent = "justinhj/hnfetch/1.0",
    compress = false
  )

{% endhighlight %}

All API calls will share the same base URL so let's define that and then constructing the query URL's is straightforward. I'll just define a few here for now...

{% highlight scala %}
  val baseHNURL = "https://hacker-news.firebaseio.com/v0/"

  def getUserURL(userId: HNUserID) = s"${baseHNURL}user/$userId.json"
  def getItemURL(itemId: HNItemID) = s"${baseHNURL}item/$itemId.json"
  val getTopItemsURL = s"${baseHNURL}topstories.json"
  
{% endhighlight %}

Actually making the query is very simple `CustomHttp(url).asString`. The `asString` part actually executes our query in a blocking manner and returns the response as string data. On success we can parse the result into case classes representing the data and we're done.

One thing to note is that uPickle handles Option types by writing them as JSON arrays. For example Option[Int](1) would be saved as [1] whilst None would saved as []. Now the Hacker News API has some mandatory fields and others that are optional. Since we can't tell the API to store options in a uPickle friendly way, we must use default values for any fields that are not mandatory. That means I needed to take the rather ugly step of defining 'missing IDs' which you can see in the code below defining the data structures we'll deal with...

{% highlight scala %}

  type HNUserID = String
  type HNItemID = Int

  val HNMissingItemID : HNItemID = -1
  val HNMissingUserID : HNUserID = ""

  case class HNUser (
                    id : HNUserID, // The user's unique username. Case-sensitive. Required.
                    //delay : Int, // Delay in minutes between a comment's creation and its visibility to other users.
                    created : Int, // Creation date of the user, in Unix Time.
                    karma : Int, // The user's karma.
                    about : String, // The user's optional self-description. HTML.
                    submitted : List[HNItemID] ) // List of the user's stories, polls and comments.

  case class HNItem(
                     id : HNItemID, // The item's unique id.
                     deleted : Boolean = false, // true if the item is deleted.
                     `type` : String, // The type of item. One of "job", "story", "comment", "poll", or "pollopt".
                     by : HNUserID = HNMissingUserID, // The username of the item's author.
                     time : Int, // Creation date of the item, in Unix Time.
                     text : String = "", // The comment, story or poll text. HTML.
                     dead : Boolean = false, // true if the item is dead.
                     parent : HNItemID = HNMissingItemID, // The comment's parent: either another comment or the relevant story.
                     poll : HNItemID = HNMissingItemID, // The pollopt's associated poll.
                     kids : List[HNItemID] = List(), // The ids of the item's comments, in ranked display order.
                     url : String = "", // The URL of the story.
                     score : Int = -1, // The story's score, or the votes for a pollopt.
                     title : String = "", // The title of the story, poll or job.
                     parts : List[HNItemID] = List(), // A list of related pollopts, in display order.
                     descendants : Int = 0 // In the case of stories or polls, the total comment count.
                   )

{% endhighlight %}

The final step is to write code to fetch and parse the data. Since the only difference between fetching a User and a Story is the type of the case class we parse, I wrote a function that is parameterized by the type and handles making the call asynchronous with errors reported in an Either ...

{% highlight scala %}

  def hnRequest[T](url: String)(implicit r: Reader[T]) : Future[Either[String, T]] = {

    Future {CustomHttp(url).asString}.map {
      response =>
        if(response.code == 200) {
          Try(read[T](response.body)) match {
            case Success(good) if good == null =>
              println("got empty")
              Left("Not found")
            case Success(good) =>
              println("got successfully")
              Right(good)
            case Failure(e) =>
              println(s"got parse error ${response.body}")
              Left("Failed to read " + e.getMessage())
          }
        }
        else {
          println("got no response")
          Left(s"Failed to retrieve $url code: ${response.code}")
        }
    }
      .recover {
        case e : Exception =>
          println(s"got exception ${e.getMessage} due to ${e.getCause}")
          Left("Failed to retrieve $url becasue ${e.getMessage}")
      }
  }

{% endhighlight %}

With all this in place writing queries is simple:

{% highlight scala %}

  // constuct the query to get an item
  def getUser(userID: HNUserID) : Future[Either[String, HNUser]] = {
    val url = getUserURL(userID)

    println(s"GET $url")
    hnRequest[HNUser](url)
  }

  def getItem(itemId: HNItemID) : Future[Either[String, HNItem]] = {
    val url = getItemURL(itemId)

    println(s"GET $url")
    hnRequest[HNItem](url)
  }

  type HNItemIDList = List[HNItemID]

  def getTopItems() : Future[Either[String, HNItemIDList]] = {
    hnRequest[HNItemIDList](getTopItemsURL)
  }

{% endhighlight %}

There are some scalatest tests that check the 'happy path', if this was a real project I would add more tests for failure's of various kinds but take a look if you are interested in the new `AsyncFlatSpec` for testing futures more conveniently.

Finally let's write a main program to test drive the functions. I've tried to make the output mirror the Hacker News home page, just for fun. One interesting thing is the part which prints relative times on the posts such as "3 minutes ago" and "2 days ago". Rather than implement that myself I imported the library `org.ocpsoft.prettytime` which makes this a breeze.

Here's a look at the code that prints a page of news items:

{% highlight scala %}

  def printPage(startPage: Int, numItemsPerPage: Int) : Unit = {

    // helper to show the article rank
    def itemNum(n: Int) = (startPage * numItemsPerPage) + n + 1

    val futureItems = getTopItems().flatMap {
      case Right(items) =>
        val pageOfItems = items.slice(startPage * numItemsPerPage, startPage * numItemsPerPage + numItemsPerPage)
        getItems(pageOfItems)

      case Left(err) =>
        Future.failed(new Exception(err))
    }

    val printItems = futureItems.map {
      _.zipWithIndex.foreach {
        case (Right(item), n) =>
          println(s"${itemNum(n)}. ${item.title} ${getHostName(item.url)}")
          println(s"  ${item.score} points by ${item.by} at ${timestampToPretty(item.time)} ${item.descendants} comments\n")
        case (Left(err), n) => println(s"${itemNum(n)}. No item (err $err)")
      }
    }

    Await.ready(printItems, 10 seconds)
  }

{% endhighlight %}

Most of this is straightforward use of Scala's concurrency library, building up a chain of futures and then waiting for them to complete, as a side effect printing the page.

First we call getTopItems which returns a `Future Either`, then flatMap it rather than map it since we want to take the result of the future (the item ids of the top items) and chain them into the call to getItems which returns a list of futures:

{% highlight scala %}

 def getItems(itemIDs : Seq[HNItemID]) : Future[Seq[Either[String, HNItem]]] = {

    val f = itemIDs.map { itemID => getItem(itemID) }
    Future.sequence(f)
  }

{% endhighlight %}

At this point we take futureItems, zip it with an index so we can label the items by nuber, then print out each item. Finally we use Await.ready to block until everything is done. Note that blocking is frowned upon but it is okay in a program like this since we need to wait for the result so we can print it out. In a more interactive program you want to keep working with futures as long as possible. 

Here's a demo run:

```
> run 0
[info] Running justinhj.hnfetch.FrontPage 0
1. BTC-E Charged in 21-Count Indictment for Laundering Funds from Hack of Mt. Gox (www.justice.gov)
  150 points by ryanlol at 5 hours ago 59 comments

2. Slack Is Raising $250M from SoftBank, Others (www.bloomberg.com)
  52 points by Element_ at 3 hours ago 20 comments

3. First Human Embryos Edited in U.S (www.technologyreview.com)
  231 points by astdb at 7 hours ago 101 comments

4. A WWII Vet Was Docked Pay for Escaping His German Captors. Now He Wants His $13 (taskandpurpose.com)
  17 points by smacktoward at 1 hour ago 0 comments

5. Britain to Ban New Diesel and Gas Cars by 2040 (www.nytimes.com)
  13 points by kimsk112 at 2 hours ago 0 comments

6. Remotely Compromising Android and iOS via a bug in Broadcom's WI-FI Chipsets (blog.exodusintel.com)
  233 points by pedro84 at 10 hours ago 97 comments

7. Google and a nuclear fusion company have developed a new algorithm (www.theguardian.com)
  272 points by jonbaer at 12 hours ago 83 comments

8. Longest Lines of Sight on Earth (beyondhorizons.eu)
  168 points by pilom at 7 hours ago 68 comments

9. Announcing the Windows Bounty Program (blogs.technet.microsoft.com)
  214 points by el_duderino at 11 hours ago 91 comments

10. An American acquitted of spying for the Soviets–even after he confessed to it (longreads.com)
  35 points by samclemens at 3 days ago 7 comments

[success] Total time: 1 s, completed 26-Jul-2017 10:58:37 PM

```


Please take a look at the source code for [hnfetch](https://github.com/justinhj/hnfetch) and play around with it. I welcome any feedback in the comments section or on Twitter.

In a future post I plan to revisit this code to demonstrate some of the cool capabilities of [47deg's Fetch](http://47deg.github.io/fetch/docs) library.
