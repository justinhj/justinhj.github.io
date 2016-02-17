---
layout: post
title:  "Hello World"
date:   2016-02-16 22:15:40 -0800
categories: blogs 
---
A sample blog

{% highlight scala %}
sealed trait Either[+E,+A] {
 def map[B](f: A => B): Either[E, B] = this match {
   case Left(l) => Left(l)
   case Right(r) => Right(f(r))
 }
{% endhighlight %}

