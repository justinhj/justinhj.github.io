---
layout: post
title:  "EitherT in ScalaZ"
date:   2016-02-16 22:15:40 -1816
tags:
- scala
- monads
- functionalprogramming
- monadtransformers
---

This post is based on the following:

[Herding Cats: Stacking Future and Either](http://eed3si9n.com/herding-cats/stacking-future-and-either.html)

In one of the projects I am working on there is a lot of code with functions like the following:

{% highlight scala %}

def getUser(id: String) : Future[Either[String, User]]

{% endhighlight %}

It's nice to be able to take the result of the concurrent calls and get either a success response or an error of some type, in this case just a string. However the problem of having two nested effects like Future and Either is that using the two together becomes a little messy.

For example consider these two functions

{% highlight scala %}

  // halves the input if it is even else fails
  def dummyFunction1(n: Int)(implicit ec : ExecutionContext) : Future[\/[String, Int]] = {
    Future.successful(
      if(n % 2 == 0)
        \/-(n / 2)
      else
        -\/("An odd number")
    )
  }

  // appends a suffix to the input after converting to a string
  // it doesn't like numbers divisible by 3 and 7 though
  def dummyFunction2(n: Int)(implicit ec : ExecutionContext) : Future[\/[String, String]] = {
    Future.successful(
      if(n % 3 != 0 && n % 7 != 0)
        \/-(n.toString + " yay!")
      else
        -\/(s"I don't like the number $n")
    )
  }

{% endhighlight %}

If I was dealing with a single layer of nesting I could easily work with these functions in a for comprehension like this:

{% highlight scala %}

 val r = for (
      rb1 <- dummyFunction1(8);
      rb2 <- dummyFunction1(12)

    ) yield (rb1 + rb2)

    r.map {
      _ shouldBe \/-(11)
    }

{% endhighlight %}

Except we can't do that because rb1 and rb2 are getting the result of the future but not inside the disjunction. And since you can't have different effect types in a for comprehension (it has to play nicely with flatmap) we are stuck with writing nested and verbose code to handle the result like this:

{% highlight scala %}

   val r: Future[Int] = dummyFunction1(8).flatMap{
      case \/-(res) => {
        dummyFunction1(12).map {
          case \/-(res2) =>
            res + res2
        }
      }
    }

{% endhighlight %}

