---
layout: post
title:  "An introduction to Monoids"
date:   2019-05-27 00:00:00 -0000
tags:
- scala
- functional programming
- monoid
---

The code in this post can be found in a complete Scala project here:

- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

## Identifying and using algebraic patterns in pure functional programs

In Scala, when practising pure functional programming, we borrow ideas from mathematics in order to describe algebraic relationships. Unfortunately, mathematical terms like Monad, Monoid and Functor, tend to give the impression we're dealing with something complicated. In fact, these algebraic structures are quite simple, and just like when we expand our vocabulary in a human language, we are able to express ourselves more richly and concisely in programming languages when we share these patterns with our compilers, and with other engineers.

In this post, I'll talk about Semigroups and Monoids; the definition, their laws and an example of how they can be used in a real program. If you're a Scala or Java programmer with some interest in pure functional programming, I hope you find this interesting. 

A semigroup is simply a type that has a binary associative operation. Which means we have a function taking two arguments of the same type and returning a single result, also of the same type. Some examples:

Integer addition forms a semigroup:

```scala
def plus(a: Int, b: Int) : Int = a + b

plus(plus(1,2),3) 
//res1: Int = 6

plus(1,plus(2,3)) 
// res2: Int = 6
```

Note that as long as we don't change the order in which the things are added together, we get the same result. It is this property, associativity, that makes addition with integers a semigroup. Multiplication works the same way:

```scala
def mulitply(a: Int, b: Int) : Int = a * b

multiply(multiply(1,2),3) 
//res1: Int = 6

multiply(1,multiply(2,3)) 
// res2: Int = 6
```

To be a semigroup the function must obey some laws. It is by adhering to these laws that an algebraic structure allows us to make assumptions about its behaviour. 

However, once you put aside the unfamiliar words, these things are not only quite simple, but they give our programs a principled theoretic grounding. Just like when we extend our vocabulary, we can communicate our ideas with precision and more conscisely.

Monoids, for example, are one of the simplest algebraic sturctures. They describe the 

...

Another example that follows the Monoid pattern is joining strings together. Take the following strings:

`"Hello" "," "World" "!"`

As long as we don't rearrange the strings, we can append them in any order we like and get the same final result

```
a b c d
ab cd
abcd
```

```
a b c d
ab c d
abc d
abcd
```

```
a b c d
a b cd
a bcd
abcd
```

This means that programs working with monoids know that they can rearrange the append operations to be more efficient, to run them in parallel and so on.

## Monoids in the wild

Maybe so far this seems a little too abstract. You already know how to append strings and sum numbers, why bother with all this fancy abstraction? Well, first of all we saw above how having a Monoid implementation enables us to use a wider range of combinators like folds and traversals; our intentions are made clearer with less code. When it comes to our application business objects, that may have more complicated append methods and be nested in multiple data structures, we can see that the expressive power of Monoids is a great advantage over an imperative solution. Let's take a look at a real example.

Recently I worked with a team of Scala developers on a backend for a China based gaming company IGG. In many MMOG (massively multiplayer online games) you manage a city that contains plots of farm land that produce food, oil and so on. On the backend we need to store the things that the player owns in a database. When in memory we represent the inventory as a map, where the keys are the types of resources we own, and the values are the quantity.

