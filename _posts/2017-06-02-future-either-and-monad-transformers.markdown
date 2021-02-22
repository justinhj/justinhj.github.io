---
layout: post
title:  "Future[Either] and monad transformers"
tags: [scala, monads, functional-programming, scalaz, monad-transformers]
---

_Disclaimer_ Monad transformers have some overhead, so make sure you benchmark before and after switching to them

If Scalaz or Hamster isn't your thing check my next post: [Future Either with Cats](/2017/06/18/future-either-with-cats.html)

When handling errors in Scala the Either type is very useful since it allows us to define the type of our right result (the success) as well as the type of the left (failure) result.

Just a warning, I use Either and \/ (ScalaZ disjunction) interchangably in this post.

Often our functions are also expected to run concurrently using a Future. When we want to combine both capabilities together we end up with type signature like this one:

{% highlight scala %}

A => Future[Either[FailureType, SuccessType]]

{% endhighlight %}

Both Either and Future are monads, which means that we can chain them together using a sequence of flatmap and map operations.

Let's consider two rather contrived functions just for exploring how Future and Either work together.

{% highlight scala %}

  // halves the input if it is even else fails
  // to investigate exception handling we will throw an ArithmeticException if n is zero
  def dummyFunction1(n: Int)(implicit ec : ExecutionContext) : Future[\/[String, Int]] = {

    if(n == 0) {
      Future.failed(new ArithmeticException("n must not be zero"))
    }
    else {
      Future.successful(
        if(n % 2 == 0)
          \/-(n / 2)
        else
          -\/("An odd number")
      )
    }

  }

  // appends a suffix to the input after converting to a string
  // it doesn't like numbers divisible by 3 and 7 though
  def dummyFunction2(n: Int)(implicit ec : ExecutionContext) : Future[\/[String, String]] = {
    Future.successful(
      if(n % 3 != 0 && n % 7 != 0)
        \/-(n.toString + " horay!")
      else
        -\/(s"I don't like the number $n")
    )
  }

{% endhighlight %}

As you can see it's a bit messy to work with Future[Either] because at each step of the computation we need to reach into the Future with map, check the Either and then pass it on to the next step.

{% highlight scala %}

  dummyFunction1(14).flatMap{
      case \/-(rb1) =>
        dummyFunction1(12).flatMap {
          case \/-(rb2) =>
            dummyFunction2(rb2 + rb1).map {
              case \/-(rb3) => rb3 // Finally we got the result
            }
        }
    }

{% endhighlight %}

Usually when we see this staircase pattern you can utilize a for comprehension to simplify things.

{% highlight scala %}

 val r = for (
      rb1 <- dummyFunction1(8);
      rb2 <- dummyFunction1(12)

    ) yield (rb1 + rb2)

    r.map {
      _ shouldBe \/-(11)
    }

{% endhighlight %}

Except we can't do that because rb1 and rb2 are getting the result of the future but not inside the disjunction. And since you can't have different effect types in a for comprehension (it has to play nicely with flatmap) we are stuck. We could extract the values from the futures in one for comprehension, then in a second one we could extract from the Eithers, but that has the problem that all of the futures have to run before our second for comprehension, and that means we could waste time completing one of the later futures when an earlier result is Left (failure) case.

Monad Transformers
------------------

Introducting EitherT. EitherT is a monad transformer, and appears in various libraries such as ScalaZ, Cats and Hamsters. For the Cats version of EitherT checkout this interesting blog post [eed3si9n](http://eed3si9n.com/herding-cats/stacking-future-and-either.html)

For ScalaZ and Hamsters keep reading!

ScalaZ (7)
----------

Using ScalaZ transformers we can write our code very similarly to the code above simply by wrapping each step in an eitherT constructor...

{% highlight scala %}

 import scalaz.EitherT.eitherT

 val r = for (
      rb1 <- eitherT(dummyFunction1(14));
      rb2 <- eitherT(dummyFunction1(12));
      rb3 <- eitherT(dummyFunction2(rb2 + rb1))

    ) yield rb3

{% endhighlight %}

That's very straightforward, and now you can see that we are able to reach into the Future result and the Either result at the same time. Behind the scenes we're constructing the transformer which when flatmapped knows how to do the steps that we would have done manually.

The only complication here is that now our result type at the end is not Future[\/[String, String]] like we'd expect but in fact is EitherT[Future, String, String]

In order to get back to where we were ScalaZ provids a run function. So the full example looks like this:

{% highlight scala %}

 import scalaz.EitherT.eitherT

 val r = for (
      rb1 <- eitherT(dummyFunction1(14));
      rb2 <- eitherT(dummyFunction1(12));
      rb3 <- eitherT(dummyFunction2(rb2 + rb1))

    ) yield rb3

  r.run // Future[\/[String, String]]

{% endhighlight %}

There is one further complication with this. In order to transform to EitherT we need a Monad[Future] otherwise we'll get a compile error as follows.

{% highlight text %}

Error:(64, 13) could not find implicit value for parameter F: scalaz.Functor[scala.concurrent.Future]

{% endhighlight %}

You don't get one for free (no pun intended) in Scalaz so let's define one as follows

{% highlight scala %}

implicit def MWEC(implicit ec: ExecutionContext): Monad[Future] = new Monad[Future ]{
    def point[A](a: => A): Future[A] = Future(a)
    def bind[A, B](fa: Future[A])(f: (A) => Future[B]): Future[B] = fa flatMap f
  }

{% endhighlight %}

There's a little bit of extra work going on here, I allow the Monad[Future] to be constructed from an execution context. The reason for that is you need to know which execution context your future is running in. By making the class this way I'm able to pick up an execution context implicitly defined in the same scope.

See this [stackoverflow question](http://stackoverflow.com/questions/44039425/specifying-an-execution-context-for-monadfuture-when-using-eithert-in-scalaz-7) (I asked it!) for more detail on this.

Here's a scala fiddle to demonstrate all this working:

<iframe height="640px" frameborder="0" style="width: 100%" src="https://embed.scalafiddle.io/embed?sfid=drq65RX/9&theme=dark&layout=v65"></iframe>

Hamsters
--------

If you don't want to bring in a big library like ScalaZ just for this feature, there is a nice micro library called [Hamsters](https://github.com/scala-hamsters/hamsters) which contains some useful utilities, one of them being FutureEither.

Using FutureEither mirrors our approach above almost exactly. The difference is we don't need to jump through hoops to make our own Monad[Future] and instead of a 'run' function, hamsters has a function 'future' which turns the FutureEither back into a Future[Either[]]

The other difference is that we're required to use the built in Scala Either instead of ScalaZ's disjuction.

{% highlight scala %}

  val r = for (
      rb1 <- FutureEither(dummyFunction1(14));
      rb2 <- FutureEither(dummyFunction1(12));
      rb3 <- FutureEither(dummyFunction2(rb2 + rb1))

    ) yield rb3

    r.future.map {
      case Right(s) =>
        // s == "13 horay!"
      case Left(e) =>
        // oops
    }

{% endhighlight %}

Hamsters has the advantage that the source code is a lot easier to read than that of Scalaz. Take a look! [MonadTransformers.scala](https://github.com/scala-hamsters/hamsters/blob/master/src/main/scala/io/github/hamsters/MonadTransformers.scala)

You can also take advantage of an implicit conversion to get rid of the need for calling 'future' at the end. Note that I added a type annotation when setting r which will make Scala look for the impclicit conversion.

{% highlight scala %}

  import io.github.hamsters.MonadTransformers.futureEitherToFuture

  val r : Future[Either[String, String]] = for (
      rb1 <- FutureEither(dummyFunction1(14));
      rb2 <- FutureEither(dummyFunction1(12));
      rb3 <- FutureEither(dummyFunction2(rb2 + rb1))

    ) yield rb3

{% endhighlight %}

Libraries used
--------------

Just for reference the libraries used when writing this post are as follow:

{% highlight scala %}

  val scalaZVersion = "7.2.8"
  
  libraryDependencies ++= Seq(
  "org.scalaz" %% "scalaz-core" % scalaZVersion,
  "org.scalaz" %% "scalaz-effect" % scalaZVersion,
  "io.github.scala-hamsters" %% "hamsters" % "1.3.1")

{% endhighlight %}


