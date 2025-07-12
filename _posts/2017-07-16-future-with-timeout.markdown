---
layout: post
title:  "Future with timeout"
tags: [scala, functional-programming, popular]
---

Previous post: [Future Either with Cats](/2017/06/18/future-either-with-cats.html)

In a small project I'm working on I needed a way to limit the amount of time my program waits for a future, returning a timeout if it takes too long. This functionality is not built into the Scala's standard [Future](http://www.scala-lang.org/api/2.12.x/scala/concurrent/Future.html) and, although you can use `Await` from `scala.concurrent`, this will block your thread which is not always desirable.

I came across several ways to achieve the result such as this post on Nami's Tech Blog [Scala Futures with Timeout](https://nami.me/2015/01/20/scala-futures-with-timeout/)

The solution here involves using Akka's `akka.pattern.after` which let's you make a future that returns a specified result (succesful or otherwise) after a specified time. Unfortunately this solution requires one to pull in Akka, which is a heavy dependency if you don't need it for anything else. 

[Akka after pattern](http://doc.akka.io/docs/akka/current/scala/futures.html#after)

Next I found the following Stackoverflow question which has several solutions [Scala Futures - built in timeout?
](https://stackoverflow.com/questions/16304471/scala-futures-built-in-timeout) but all of them dependencies you may not want including the Play framework and Akka.

Taking these solutions as inspiration I wrote my own that has no dependency outside the Scala and Java library. It uses a thread that sleeps for the duration of the timeout then throws an exception. By using `Future.firstCompletedOf` with the timeout future and the callers future we have achieved our goal.

{% highlight scala %}

  // SAMPLE CODE ONLY, DO NOT USE AS THIS CREATES A BLOCKING THREAD FOR EVERY FUTURE THAT USES IT
  
  def futureWithTimeout[T](future : => Future[T], timeout : FiniteDuration)(implicit ec: ExecutionContext): Future[T] = {

    lazy val timeoutF = Future {

      Thread.sleep(timeout.toMillis)

      throw new TimeoutException()
    }

    Future.firstCompletedOf(List(timeoutF, future))

  }

{% endhighlight %}

Well this is fine in that it works, but as noted in my comments we need to create a thread that also blocks using `Thread.sleep`. Remember our initial goal was to do this without any blocking certainly with bringing an additional thread into the picture.

The next step was to determine how to make the timeout happen without starting a new thread and without any blocking. To the rescue comes [java.util.Timer](https://docs.oracle.com/javase/7/docs/api/java/util/Timer.html) which we can use to trigger the timeout event in the future. `Timer` has some very nice properties: It's built into Java, it uses one thread per timer, it is thread safe and it is designed to manage thousands of active Timer events on each Timer object.

In order to use the Timer we need a `TimerTask` which is a simple `Runnable` object. Here's what's happening in the code below:

1. User calls futureWithTimeout
2. We create a promise with which to complete the future
3. We start a timer task which will run at the timeout
4. When the timeout occurs we complete the promise with `TimeoutException` if it is not already complete
5. When the user's future completes we succesfully (or otherwise) complete the `Promise` if it has not alread been completed
6. Return the Promise's future to the user

{% gist e2eb081af1f8a341f957e2f8bc4e9686 %}

Here's a small test suite showing the two cases for the users future succeeding and the users future timing out:

{% gist 1de64d25af06dd2c38289c680c3d5a3c %}

I've add this code to the StackOverflow question about Scala and Future timeouts. If you want to go there and upvote (or downvote) the link is here:

[Scala Futures - built in timeout?](https://stackoverflow.com/questions/16304471/scala-futures-built-in-timeout/45272591#45272591)

And finally a quick demo of this in action using Li Haoyi's awesome [Ammonite REPL](http://ammonite.io/#Ammonite-REPL)

![Timeout Example](/../images/timeout.gif)







