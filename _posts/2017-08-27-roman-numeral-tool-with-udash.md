---
layout: post
title:  "Roman numeral tool with Udash"
date:   2017-08-27 00:00:00 -0000
tags: [scala, scala.js, clojure-script, functional-programming, udash]
---

In this post I'll walk through building this Roman numeral to decimal converter using Scala.js and the [Udash](http://udash.io/) web application framework

<iframe width="560" height="315" src="https://www.youtube.com/embed/vH3eVXAyhbs?controls=0&amp;showinfo=0" frameborder="0" allowfullscreen></iframe>

See the project on Github [Udashroman](https://bitbucket.org/justinhj/udashroman/)

# Clojurescript to Scala

Several years ago when I was working through the Clojure exercises on [4clojure.org](http://www.4clojure.com) I implemented conversion from decimal numbers to roman numerals [Write Roman Numerals](http://www.4clojure.com/problem/104) and the same thing in reverse [Read Roman Numerals](http://www.4clojure.com/problem/92). Next, when learning how to write Clojurescript web frontends, I implemented a simple web app to do the conversion live as you make changes to either the decimal or roman inputs which is modelled on the conversion UI you may see on Google when converting between pounds and kg and so on.

You can try out this clojurescript version of the app here [romanclojure](http://heyes-jones.com/romanclojure/roman.html) and the source code is available at [http://github.com/justinhj/cljs-roman](http://github.com/justinhj/cljs-roman). The code consists of a single, quite concise, Clojurescript source file [main.cljs](https://github.com/justinhj/cljs-roman/blob/master/src/cljs/roman/main.cljs) 

# Building an app with Udash

Udash is designed to write rich single page apps and using the provided project generator to create one with some sample pages made it really easy to get started although I'd recommend skimming through most of the [Udash guide](http://guide.udash.io/) before you start. 

After creating my project I modified the `RoutingRegistryDef` which defines the routing rules to map the URL to the individual views of your application. In my case there is only one page so this is straightforward.

{% highlight scala %}

  private val (url2State, state2Url) = Bidirectional[String, RoutingState] {
    case "" => RomanConverterState
  }

{% endhighlight %}

It is good practise to separate your application's business logic from UI code to make it more testable, and by not having any dependencies on other libraries it is easy to move into another project if you need to. For that reason I created a companion object `com.justinhj.romanconvert.Convert` which contains functions to convert back and forth between Roman and Decimal. If you compare my original [Clojurescript](https://github.com/justinhj/cljs-roman/blob/master/src/cljs/roman/main.cljs) with the new [Scala](https://bitbucket.org/justinhj/udashroman/src/867a30375d44b6d98ce42bfc1e572f65f0dca3ef/src/main/scala/com/justinhj/romanconvert/Convert.scala?at=master&fileviewer=file-view-default) code you can see that the functions converted quite cleanly. The only complication I ran into is that the Scala standard library does not have an exact equivalent of Clojure's `partition` function which I use as part of the conversion.

As an example if you pass in "IX" then I will map that to the pairs `List((1, 10), (10, 0))` and if you pass "XI" I want `List((10, 1), (1, 0))`. In other words we pair each value with the one before it and use 0 as a pad value when we run out at the end. Scala's partition function `sliding` does not allow this default pad value. In order to get around this I instead implemented the function `pairUp` to do exactly what I needed in this case. 

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

My validators are fairly simple and only check that your Roman property contains valid Roman numeral characters whilst the decimal one will ensure that you are converting a positive non-zero number less that a certain maximum (since large numbers quickly fill up the screen with M's!). As a bonus we can use the validators to modify the class of the inputs to .error which will highlight the field in red as shown below:

<iframe width="560" height="315" src="https://www.youtube.com/embed/2PnsV4Ph18A?controls=0&amp;showinfo=0" frameborder="0" allowfullscreen></iframe>

In the original Clojure app I used the [Dommy](https://github.com/plumatic/dommy) library to add listeners to each field to make the conversion when the input changes. In Udash the same thing is done using the `listen` callback on properties. By adding a listener to decimal and roman sub properties of our model, if the user changes them our code will get triggered.

Let's look at handling a change to the roman property, the decimal one is similar. As you can see we define the listen callback as a function which will call validate on the property and only proceed if the result is `Valid`. Folowing that we trigger the conversion and if all is well call `set` on the sub property to update the decimal value. 

{% highlight scala %}

    model.subProp(_.roman).listen{ r =>

      model.subProp(_.roman).isValid.onComplete {
        case Success(Valid) =>
          Convert.safeRomanNumeralsToDecimal(r) match {
            case Right(converted) => model.subProp(_.decimal).set(converted)
            case Left(err) => println(s"$r roman convert error $err")

          }

        case Success(errors) => println(s"$r has validation errors $errors")

        case Failure(err) => println(s"validating $r caused exception $err")

      }
    }

{% endhighlight %}

So far so good but we don't yet have any HTML markup for the user to interact with. The last piece is the view itself which takes the model and presenter as parameters as it needs to work with both of them:

{% highlight scala %}

class RomanConverterView(model: ModelProperty[ConversionModel], presenter: RomanConverterPresenter)

{% endhighlight %}

In the clojurescript code I needed to write the HTML code fro the page and then have the script itself interact with it. In the Udash version I can write the HTML using [ScalaTags](https://github.com/lihaoyi/scalatags) directly in the code for the view.

{% highlight scala %}

  private val content = div(
    h2("Roman Numerals Converter"),
    div(cls := "col-md-6",
      convertForm,
      div(DemoStyles.textVOffset),
      div(`class`:="container",
        "Scala.js source code on ", Image("bitbucket.png", "Bitbucket source", DemoStyles.logo), " ", 
        a(DemoStyles.underlineLinkGrey,
          href:=ExternalUrls.bitbucketSource, ExternalUrls.bitbucketSource)
      ),
      div(`class`:="container",
        "Made with ", Image("udash_logo.png", "Udash Framework", DemoStyles.logo), " ",
        a(DemoStyles.underlineLinkGrey,
          href:=ExternalUrls.homepage, "UDash"),
        " Scala web framework"
      )
    )
  )

  override def getTemplate: Modifier = content

{% endhighlight %}

`getTemplate` is a function in the view that the Udash library will call to render our page and my method `content` contains the markup needed to do so.

As you can see a piece of markup is just a function call and I call `convertForm` to generate the html for the actual input fields which is as follows:

{% highlight scala %}

  def convertForm: Modifier = 
    div(
      UdashForm( 
        UdashForm.numberInput
          (validation = Some(UdashForm.validation(model.subProp(_.decimal))))
          ("Decimal")
          (model.subProp(_.decimal)),
        div(DemoStyles.center,
          div(`class` := "glyphicon glyphicon-chevron-up"),br,
          div(`class` := "glyphicon glyphicon-chevron-down")),
        UdashForm.textInput
          (validation = Some(UdashForm.validation(model.subProp(_.roman))))
          ("Roman")
          (model.subProp(_.roman))
      ).render)

{% endhighlight %}

The interesting part here is the `validation` parameter of the inputs. This is what enables Udash to give the user visual feedback when validation fails.

# Summary

My key takeaways from this mini-project are that converting Clojurescript to Scala.js is quite painless, and I will certainly use the Udash web more in future.

Pros

* A large and well documented library
* Write your entire frontend and backend in the same library in the same language including type checked CSS and HTML
* Project generator to get started

Cons

* You need to read the whole guide
* No reference manual so if something is not in the guide you will have to read the source code (this was an issue with ScalaCSS too)
* Need to know Scala to create the web content (a template approach like Play/Twirl may work better if you work with designers that don't use Scala)









