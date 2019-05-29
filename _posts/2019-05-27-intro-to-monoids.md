---
layout: post
title:  "An introduction to Monoids"
date:   2019-05-27 00:00:00 -0000
tags:
- scala
- functional programming
- monoid
---

- TODO Clever Quote about concatenation - Somebody famous

Source code on Github:

- [https://github.com/justinhj/monoid-demo](https://github.com/justinhj/monoid-demo)

# Identifying and using algebraic patterns in pure functional programs

In Scala, when practising pure functional programming, we borrow ideas from mathematics in order to describe algebraic relationships. It's a source of fear and/or confusion that words like Monad, Monoid, Functor and Applicative show up in relatively simple Scala programs. 

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

```
Map(



