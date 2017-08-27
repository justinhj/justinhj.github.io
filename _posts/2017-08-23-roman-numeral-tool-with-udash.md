---
layout: post
title:  "Roman numeral tool with Udash"
date:   2017-08-27 00:00:00 -0000
tags:
- scala
- functional programming
- udash
- roman numerals
---

Github project related to this post [Udashroman](https://bitbucket.org/justinhj/udashroman/)

Several years ago when I was working through the Clojure exercises on [4clojure.org](link.com) I implemented conversion from decimal numbers to roman numerals [LINK?](link) and the same thing in reve [LINK?](link?). Next, when learning how to write Clojurescript web frontends, I implemented a simple web app to do the conversion live as you make changes to either the decimal or roman inputs. The conversion code works very much like the conversion tools you get when searching Google for a conversion between say grams and ozs.

<iframe width="560" height="315" src="https://www.youtube.com/embed/vH3eVXAyhbs?rel=0&amp;showinfo=0" frameborder="0" allowfullscreen></iframe>

You can try out the app here [romanclojure](http://heyes-jones.com/romanclojure/roman.html) and the source code is available at [http://github.com/justinhj/cljs-roman](http://github.com/justinhj/cljs-roman)

I decided to port this code to Scala to investigate the [Udash web framework](http://udash.io/) and as an exercise in porting Clojure code to Scala. 

Although my work is mostly with backend Scala systems, increasingly I need to work on frontend tools for monitoring, managing and deploying clusters of servers, and have been using Spray, Twirl and handcrafted Javascript in order to supply interactive pages from the backend to client browsers. I decided to try out the [Udash web framework](http://udash.io/) which lets you write your frontend code in Scala. This would enable me to put more functionality in the frontend as well as create a faster more seamless single page experience.

Udash is designed to write rich single page apps, and using the provided project generator to create one with some sample pages made it really easy to get started. I did find I had to read almost the entire [Udash manual](link) to get anywhere as I kept running into roadblocks. Everything you need to know is in the documentation, but you won't know where to look unless you've had at least a cursory glance at each page.

After creating my project I modified the RoutingRegistryDef which defines the routing for the app so that only my page gets loaded:

{% highlight scala %}

  private val (url2State, state2Url) = Bidirectional[String, RoutingState] {
    case "" => RomanConverterState
  }

{% endhighlight %}

As is good practise, I wanted to keep the actual conversion code separate from the actual web app so I created a Convert companion object which contains functions to convert back and forth between Roman and Decimal. If you compare the [clojure] code with the new [Scala] code you can see that the original functions port quite straightforwardly. The only complication I ran into is that the Scala standard library does not have Clojure's `partition` function. You can come close with `???` but it does not allow you to fill in a default value at the ends which is what we needed (TODO explain more) so I made a function `pairUp` specifically for this purpose.

With the conversion code in place the rest of the work is making the web app. All of the code is in `RomanConverterView.scala` and I'll walk through the pieces from top to bottom.

In Udash your application data is represented as a Property. You can aggregate several fields together to make a ModelProperty and that's what I've done in this case. The data for our application consists of the current decimal number and the current roman numeral.

{% highlight scala %}

trait ConversionModel {
  def decimal: String
  def roman: String
}

{% endhighlight %}

Next we need a ViewPresenter which is used by Udash to create a `presenter` and `view` and in our case is very simple as you can see in the code for `RomanConverterViewPresenter`. It creates a model and passes that to both the `Presenter` which will handle business logic and the `View` which will handle the rendering of our application.

next steps continue working through that file

round up










