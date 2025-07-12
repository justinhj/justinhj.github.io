---
layout: post
title:  "Future[Either] with Cats"
date:   2017-06-18 10:00:40 -0000
tags: [scala, monads, eithert, functional-programming, cats, monad-transformers, popular]
---

_Disclaimer_ Monad transformers have some overhead, so make sure you benchmark before and after switching to them

In a [previous post](http://justinhj.github.io/2017/06/02/future-either-and-monad-transformers.html) I was exploring the use of the EitherT to make it easier to work with Either when it is nested in a Future. I'm currently reading the book [Advanced Scala with Cats](http://underscore.io/training/courses/advanced-scala/) and decided to rewrite some of my code using the Cats library instead.

There's also a page on [Herding Cats](http://eed3si9n.com/herding-cats/stacking-future-and-either.html) where Eugene Yokota covers the same ground. I wanted to expand my examples from last post so that they actually execute in a Future so I can map that to my own error handling code in real programs. For example in the Herding Cats blog the demonstration code returns values like this:

{% highlight scala %}

  EitherT.right(Future { List(User(1, "Michael")) })

{% endhighlight %}

What I wanted to figure out was how this looks in real code where you may have a function that works with a Future[Either]. I went back to my code from last post and modified the dummy functions so that:

* The code executes in a Future
* The function returns Cats EitherT type response

This makes things easier at the call site because instead of converting the response from Future[Either[String, A]] as I did then, you can simply use the EitherT directly. So instead of:

{% highlight scala %}

 val r: FutureEither[String, Int] = for (
        rb1 <- FutureEither(dummyFunction1(8));
        rb2 <- FutureEither(dummyFunction1(12))
      ) yield rb1 + rb2

{% endhighlight %}

you can use the results directly

{% highlight scala %}

  {for (
      rb1 <- dummyFunction1(8);
      rb2 <- dummyFunction1(12)

    ) yield (rb1 + rb2)}

{% endhighlight %}

If you check the example below the only thing needed to make your function return an EitherT[Future] is to use the EitherT constructor on the final value

{% highlight scala %}
   EitherT[Future, String, Int](f)

{% endhighlight %}

The other thing you need to know about EitherT in Cats is that you need to use 'value' instead of 'run' to get into the results at the end.

I found [this post](http://blog.leifbattermann.de/2017/03/16/7-most-convenient-ways-to-create-a-future-either-stack/) useful for more ways to create a Future[Either] stack.

<iframe height="640px" frameborder="0" style="width: 100%" src="https://embed.scalafiddle.io/embed?sfid=bcUycnS/35&theme=dark&layout=v66"></iframe>

Final thoughts; whilst the the syntax is slightly different when working with EitherT and Cats, Scalaz and the Hamsters library, the concept is the same and it comes down to finding a way to use them that makes them easier to work with at the calling site. I think I can make things even cleaner with an implicit conversion from Future[Either] to EitherT[Future, String, A] but that will be possibly a later post.

Libraries used
--------------

Again for reference the libraries used when writing this post are as follow:

{% highlight scala %}

   "org.typelevel" %% "cats" % "0.9.0"

{% endhighlight %}


