---
layout: post
title:  "Hacker News API Part 3"
date:   2017-10-08 00:00:00 -0000
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

Github project related to this post [hnfetch](https://github.com/justinhj/hnfetchjs)

Last time I presented a simple command line app that used the [Fetch] library to pull data from an online data source (the [Hacker News API]). This new Github repo extends that with the following goals:

- Convert the code from a command line JVM app to a Scala.js app that runs in the browser
- Visualize each round of the data fetch using [reftree]
- Use [Udash] to create an interactive frontend to operate the fetches
- Create a custom cache so we can query its size and clear it on demand

# Some gory details on Fetch

Fetch is inspired by the Haskell library [Haxl] developed at Facebook to simplify the retrieval of data from multiple sources. You can read more about that [here].

With Fetch you describe what you want to retrieve by creating your own DataSources that describe how to retreive data from some (usually) remote source. You can set various parameters such as how many items to retrieve at once and whether to run concurrently or sequentially and how long to wait before timing out. When you later ask it to retrieve some data you pass the IDs for that data and it will build a plan made up of a Queue of Rounds which you can then execute. Note that nothing runs until you tell it to. Under the hood Fetch is built using [Free Monads]. Whilst that is a complex topic, as a user of the library it just means that you can declare the job you want done and then choose an "interpreter" to execute it against. In our case we will use the built in [FutureMonadError] which executes the jobs using Scala Futures. There is additional support for things such as Twitter Futures, Monix Tasks or you can run the fetch synchronously using the [Eval] Monad from [Cats].

# Converting code to scala.js

This is the first time I've ported code I wrote to run on the JVM to Scala.js so it was a learning experience but also the shortest part of the project. I created a Udash frontend using the built in project generator and started moving my code into the new project a piece at a time. Here are the steps I needed:

## Change library import paths

```
    "com.47deg" %%% "fetch" % "0.6.3",
    "com.lihaoyi" %%% "upickle" % "0.4.4",
    "org.typelevel" %%% "cats" % "0.9.0",
```

This part was trivial since these libraries are all available for scala.js. You just change the first `@@` to `@@@` and the scala.js library will be imported instead.




[about reftree](https://www.youtube.com/watch?v=6mWaqGHeg3g)

{% highlight scala %}

import poo

{% endhighlight %}

Converting to scala.js
----------------------

had to use https://www.scala-js.org/doc/interoperability/facade-types.html

scala.js mostly worked without changes notably cats, fetch, upickle 

no need for a http library because can use javascript ajax functions

replace prettytime java library with moments.js