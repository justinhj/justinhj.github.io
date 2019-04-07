---
layout: post
title:  "Processing large Redis databases with Eredis in Emacs Lisp"
date:   2019-02-23 00:00:00 -0000
tags:
- emacs
- functional programming
- redis
- emacs lisp
- elisp
---

In a [previous article](2018/11/19/eredis-updated-emacs-redis-api.html) I wrote about using eredis, a package that lets you access the Redis API from Emacs lisp. Towards the end I discussed support for using the Redis `SCAN` command to page through large databases without blocking Redis or overwhelming our process with having the whole key/value set in memory at once.

Wrapping SCAN in helper functions worked well for the "each" functions (executing a function for each key/value for side effects only) and the "reduce" functions (iterating over the key/values and accumulating a single value). What I didn't go into was how to map over the key/values, in fact I warned against it, because you don't want to create huge lists in Emacs and slow everything down. In this article I will show how you can use the stream package, written by Nicolas Petton, to compose as many map, filter and other operations as you want, without blowing up your computer!

The basis for this technique is to implement a generator that wraps the process of running the Redis [SCAN](https://redis.io/commands/scan) until we run out of pages, and returning one item at a time like an iterator. 

Generators are an advanced concept, in terms of implementation, but fortunately for the purposes of this article, Chris Wellons has written a very nice exposition of how they work in Emacs lisp which you can read here [https://nullprogram.com/blog/2018/05/31/](https://nullprogram.com/blog/2018/05/31/)

If you don't want to know the inner workings of generators the just understand them as a way to write a function that produce a value then suspend itself in the current state until the caller would like to produce another value. Here's a simple example:

{% highlight bash %}
(require 'generator)
(require 'seq)
(iter-defun page-seq(seq page-size)
  (let ((s seq))
    (while (not (null s))      
      (iter-yield (seq-take s page-size))
      (setq s (seq-drop s page-size)))))
(setq g1 (page-seq '(1 2 3 4 5) 2))
(iter-next g1) ;; (1 2)
(iter-next g1) ;; (3 4)
(iter-next g1) ;; (5)
(iter-next g1) ;; Debugger entered--Lisp error: (iter-end-of-sequence)
{% endhighlight %}

`iter-defun` is a macro that lets you write otherwise normal emacs lisp functions but that have the ability to return values and suspend using `iter-yield` at any point. In this example my function page-seq let's us iterate over any sequence in pages of the specified size page-size . Each time the caller uses our generator they will get either a full page, a partial page from the end of the list or an error is thrown for end of sequence.

Using eredis we can now easily write a generator for paging over Redis keys and values like this:

{% highlight bash %}
(iter-defun eredis--key-value-generator(&optional process)
  "Create a generator that scans across the entire set of Redis keys and their values using the current Redis process or the specified PROCESS"
  (let (cursor)
    (while (not (string-equal "0" cursor))
      (destructuring-bind (new-cursor keys)
   (eredis-scan (if cursor cursor "0") process)
 (setq cursor new-cursor)
 (let ((values (apply #'eredis-mget (-snoc keys process))))
   (while (> (length keys) 0)
     (iter-yield (cons (car keys) (car values)))
     (setq keys (!cdr keys)
    values (!cdr values))))))))
{% endhighlight %}
	
All that I've done here is slightly modify the code that pages over Redis so that the function is now an iter-defun. After each SCAN I run MGET to get the values for each key, then return each key using iter-yield until the current list is exhausted, then repeat the SCAN and so on until we run out of values. You can see that the generator makes this kind of iteration with state very easy to do.

It's a little bit fiddly to use because the generator throws an error when it's empty but that's no problem, because as I said earlier we will use the stream package to make using the generator completely transparent to the user. Only the function stream-from-iterator is needed to make that conversion from generator to stream.

{% highlight bash %}
(require 'eredis)
(eredis-version)
(setq rp (eredis-connect "localhost" 6379))
(setq g1 (eredis--key-value-generator rp))
(setq s1 (stream-from-iterator g1))
{% endhighlight %}

