---
layout: post
title:  "Intro to Monoids"
date:   2019-05-27 00:00:00 -0000
tags:
- scala
- functional programming
- monoid
---

Source code on Github:

- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

# Monoids

In Scala, when practising pure functional programming, we borrow ideas from mathematics in order to describe algebraic relationships. Unfortunately, mathematical terms like Monad, Monoid and Functor, tend to give the impression we're dealing with something complicated. In fact, these algebraic structures are quite simple, and just like when we expand our vocabulary in a human language, we are able to express ourselves more richly and concisely in programming languages when we share these patterns with our compilers, and with other engineers.

For now, I'll talk about Semigroups and Monoids; what they are and how they can be used in real programs. This will be aimed at Scala or Java programmers with some interest in learning to program in a pure functional way. A semigroup is simply a type that has a binary associative operation. Which means we have a function taking two arguments of the same type and returning a single result, also of the same type. Some examples:

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



