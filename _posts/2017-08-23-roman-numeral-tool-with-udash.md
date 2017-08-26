---
layout: post
title:  "Roman numeral tool with Udash"
date:   2017-08-27 00:00:00 -0000
tags:
- scala
- scala.js
- functional programming
- udash
- roman numeral conversion
---

Github project related to this post [Udashroman](https://bitbucket.org/justinhj/udashroman/)

Several years ago when I was working through the Clojure exercises on [4clojure.org](link.com) I implemented conversion from decimal numbers to roman numerals [LINK?](link) and the same thing in reve [LINK?](link?). Next, when learning how to write Clojurescript web frontends, I implemented a simple web app to do the conversion live as you make changes to either the decimal or roman inputs which is modelled on the conversion UI you may see on Google when converting between pounds and kg and so on.

You can try out this clojurescript version of the app here [romanclojure](http://heyes-jones.com/romanclojure/roman.html) and the source code is available at [http://github.com/justinhj/cljs-roman](http://github.com/justinhj/cljs-roman)

I decided to port this code to Scala to investigate the [Udash web framework](http://udash.io/) and as an exercise in porting Clojure code to Scala and to give Udash a test drive on a nice simple project.

Udash is designed to write rich single page apps and using the provided project generator to create one with some sample pages made it really easy to get started. I did find I had to read almost the entire [Udash manual](link) to get anywhere as I kept running into roadblocks. Everything you need to know is in the documentation, but you won't know where to look unless you've had at least a cursory glance at each page. For example it took me a while to figure out why I was getting compile errors when copying Bootstrap style examples from the manual, when I'd missed an earlier part of the manual that showed how to add the bootstrap part as a separate library in your build.

After creating my project I modified the RoutingRegistryDef which defines the routing for the app so that only my page gets loaded:

{% highlight scala %}

  private val (url2State, state2Url) = Bidirectional[String, RoutingState] {
    case "" => RomanConverterState
  }

{% endhighlight %}

It's good practise to separate your business logic from UI code to make it more testable, and by not having any dependencies on other libraries it is easy to move into another project if you need to. For that reason I created a companion object `com.justinhj.romanconvert.Convert` which contains functions to convert back and forth between Roman and Decimal. If you compare my original [clojure] code with the new [Scala] code you can see that the original functions ported quite straightforwardly. The only complication I ran into is that the Scala standard library does not have Clojure's `partition` function. You can come close with `???` but it does not allow you to fill in a default value at the ends which is what we needed (TODO explain more) so I made a function `pairUp` specifically for this purpose.

Please be aware that one the goals of 4Clojure puzzles is to solve the problem with as little code as possible as there is a code golf leaderboard for each one. For that reason my original Clojure code has no comments and is not written in what I'd call a maintable style. In porting to Scala I did try to make it more readable and so it is a little more verbose.

With Udash each page of your app requires a number of classes defined to make the view work and since our app is only one page all of the code is in `RomanConverterView.scala` and I'll walk through the pieces from top to bottom.

Your application data is represented as a Property. You can aggregate several fields together to make a ModelProperty and that's what I've done in this case. The data for our application consists of the current decimal number and the current roman numeral. 

{% highlight scala %}

trait ConversionModel {
  def decimal: String
  def roman: String
}

{% endhighlight %}

Next we need a ViewPresenter `RomanConverterViewPresenter` which is used by Udash to create a `presenter` and `view` and in our case is very simple as you can see in the code for `RomanConverterViewPresenter`. It creates a model and passes that to both the `Presenter` which will handle business logic and the `View` which will handle the rendering of our application.

`RomanConverterPresenter` represents the interactive portion of our app and is responsible for validating the data in the model and converting from decimal to roman when the properties change. The method `handleState` is an initialization function called when the state becomes active. It adds a `Validator` to each property. With that in place you can check if an input is valid using the `isValid` method. Interestingly this returns a `Future` indicating that you could perhaps perform some web request or other IO operation without blocking Javascript's single thread.

My validators are fairly simple and only check that your Roman property contains valid Roman numeral characters whilst the decimal one will ensure that you are converting a positive non-zero number less that a certain maximum (since large numbers quickly fill up the screen with M's!).

In the original Clojure app I used the TODO library to add listeners to each field to make the conversion when the input changes. In Udash the same thing is done using the `listen` callback on properties. By adding a listener to the decimal and 










