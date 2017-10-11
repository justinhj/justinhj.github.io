---
layout: post
title:  "Hacker News API Part 3"
date:   2017-10-08 00:00:00 -0000
tags:
- scala
- functional programming
- Hacker News
- fetch
- typelevel
---

Previous post: [Hacker News API part 2](/2017-07-30-hacker-news-api-2.html)

Github project related to this post [hnfetch](https://github.com/justinhj/hnfetchjs)

In two previous related posts I explored using Scala to make HTTP requests and parse the results, using the Hacker News API as an example. Then I moved on to a more robust method using the Fetch library. Fetch also cross-compiles to Scala.js, so I decided to update my code from a simple command line app to a UDash(link) web application. As a bonus I used the reftree(link) library to visualize how the Fetch library proceeded to retrieve the data, in this case Hacker News stories, that we asked for.

With Fetch you describe what you want to retrieve using DataSources. In this definition you tell it how to get the data and can set various parameters such as how many items to retrieve at once and whether to run concurrently or sequentially. When you later ask it to retrieve some data you pass the IDs for that data and it will build a plan made up of a Queue of Rounds which you can then execute. Note that nothing runs until you tell it to; under the hood Fetch is built on Free Monads. You declare the job you want done and then choose an interpreter to execute it. In our case we will use the built in FutureMonadError(check) which executes the jobs in Futures.

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