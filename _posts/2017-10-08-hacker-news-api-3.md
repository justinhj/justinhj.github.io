---
layout: post
title:  "Hacker News API Part 3"
date:   2017-10-11 00:00:00 -0000
tags:
- scala
- functional programming
- Hacker News
- Hacker News API
- fetch
- typelevel
- reftree
- scala.js
---

Previous post: [Hacker News API part 2](/2017-07-30-hacker-news-api-2.html)

Github project related to this post 

- [hnfetch](https://github.com/justinhj/hnfetchjs)

![Frontend example](/../images/ux.png)

Last time I presented a simple command line app that used the [Fetch] library to pull data from an online data source (the [Hacker News API]). This new Github repo extends that with the following goals:

- Convert the code from a command line JVM app to a Scala.js app that runs in the browser
- Create a custom cache so we can query its size and clear it on demand
- Use [Udash] to create an interactive frontend to operate the fetches
- Visualize each round of the data fetch using [reftree]

Here's the page hosted on my website

- [http://heyes-jones.com/hnfetch/index.html](http://heyes-jones.com/hnfetch/index.html)

And a short video demonstration

- [https://youtu.be/0jHG8Y3hiog](https://youtu.be/0jHG8Y3hiog)

# What is Fetch?

Fetch is inspired by the Haskell library [Haxl](https://github.com/facebook/Haxl) developed at Facebook to simplify the concurrent retrieval of data from multiple sources. You can read more about that [There is no Fork: an Abstraction for Efficient, Concurrent, and Concise Data Access](https://simonmar.github.io/bib/papers/haxl-icfp14.pdf)

You can read more about Fetch at their documentation page [https://47deg.github.io/fetch/docs.html](https://47deg.github.io/fetch/docs.html)

# Converting code to scala.js

This is the first time I've ported code written for the JVM to Scala.js so it was a learning experience but also the shortest part of the project. I created a Udash frontend using the built in project generator and started moving my code into the new project a piece at a time. It involved doing the following:

## Change library import paths

```
    "com.47deg" %%% "fetch" % "0.6.3",
    "com.lihaoyi" %%% "upickle" % "0.4.4",
    "org.typelevel" %%% "cats" % "0.9.0"
```

This part was easy since these libraries are all available for scala.js. You just change the first `@@` to `@@@` and the scala.js library will be imported instead.

## Java libraries

In my original code I used the PrettyTime library which is written in Java

```
"org.ocpsoft.prettytime" % "prettytime" % "3.2.7.Final"
```

and is not available to Scala.js since all code must be either compiled from Scala or Javascript. I found a similar library to PrettyTime called moment.js which had the functionality I needed. In order to use a Javascript library you must add it to the Assets folder and load it on your pages, and you need a [facade type](https://www.scala-js.org/doc/interoperability/facade-types.html) to wrap the Javascript API. Fortunately there is one already for the moment.js library, so by important that you can immediately start using it as if it were a Scala library.

```
    "ru.pavkin" %%% "scala-js-momentjs" % "0.9.0"
```

## Replace the scalaj-http

Since fetching HTTP pages in my original code uses the ScalaJ HTTP library

```
  "org.scalaj" %% "scalaj-http" % "2.3.0"
```

and this is not available in a scala.js version, I had to look elsewhere. Fortunately Javascript comes with the functionality needed to make requests to a a http endpoint. This is exposed to the Ajax library in scala.js. So removing the scalaj library and replacing the calls with Ajax was all that was needed.

# Custom DataCache

The DataCache interface in Fetch allows you to update the cache with new elements and to get a particular element from the cache if it is there. In order to write an interactive tool to explore Fetch I wanted to be able to show the number of elements in the cache. I also wanted to be able to empty the cache, but that's straightforward, you just replace the existing cache with a new empty one.

Take a look at the code in `com.justinhj.hnfetch.Cache` for a DataCache capable of returning its size.

# Udash frontend

The [Udash guide](http://guide.udash.io) tells you everything you need to know to make great interactive frontends entirely in Scala. I've used the Bootstrap add-on to utilize features such as tabbed panes to switch between the stories and the fetch diagram.

# Visualizing the Fetch rounds

Probably the most interesting part of this project, although it was also fairly easy to implement, was the visualization of each fetch round. 

For this I used reftree, and you can find out more about it in this video [https://www.youtube.com/watch?v=6mWaqGHeg3g](https://www.youtube.com/watch?v=6mWaqGHeg3g)

Reftree takes care of the hard part of rendering the view using Javascript's Vis.js (or GraphViz on the JVM), you just need to be able to translate your data into a `RefTree` by writing an implicit conversion:

{% highlight scala %}

  implicit def fetchInfoToRefTree: ToRefTree[FetchInfo] = ToRefTree[FetchInfo] {
    fetchInfo =>
      RefTree.Ref(fetchInfo, Seq(
        RefTree.Val(fetchInfo.count).toField.withName("count"),
        fetchInfo.dsName.refTree.toField.withName("datasource")

      ))

  }

  implicit def roundToRefTree: ToRefTree[Round] = ToRefTree[Round] {
    round =>
      val fetchInfos : List[FetchInfo] = getRoundCountAndDSName(round)

      RefTree.Ref(round, Seq(
        RefTree.Val((round.end - round.start) / 1000000).toField.withName("ms"),
        fetchInfos.refTree.toField.withName("Fetches")
      ))

  }
  
{% endhighlight %}

Here's a sample diagram of the Fetch rounds

![Fetch diagram](/../images/fetch.png)

Here you can see that each round grabbed at least 8 items (that's the number of items per round my data source specifies) and you can see the time in ms for each one.

# Next steps

Feel free to fork the code on github and expand it your needs, and as always feel free to contact me at the links above with any questions or comments.









