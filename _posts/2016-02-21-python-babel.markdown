---
layout: post
title:  "Using Python in org-mode"
date:   2016-02-16 22:15:40 -1816
tags: [blogging, emacs, python] 
---

This is my first post since I moved my technical blog from [justinsboringpage.blogspot.ca](http://justinsboringpage.blogspot.ca) to right here on [Github pages](https://pages.github.com) 

All the old posts have been migrated over automatically. Github pages supports a sophisticated static site generator called Jekkyl. Sophistication is a double edged sword. On the one hand it offers a lot of power and flexibility, and on the other a simple mistake will make the site fail to build with an obscure Ruby error message. Hopefully it is worth the trade off.

Org-mode, babel and literate programming
----------------------------------------

Org mode supports literate programming, which can be defined as follows:

"Literate programming is an approach to programming introduced by Donald Knuth in which a program is given as an explanation of the program logic in a natural language, such as English, interspersed with snippets of macros and traditional source code, from which a compilable source code can be generated."

See here for more:

[Babel: active code in Org-mode](http://orgmode.org/worg/org-contrib/babel/)

In practise what this allows is to put fragments of source code into an org mode file, which can even be in different languages, hence the name Babel. Each source code block can be evaluated with parameters passed from other blocks. Data can be read from, and written to, org mode tables.

This is clearly a very powerful feature. For now here's a very simple example. I run some Python code to get the Python version and then insert it into an org table.

Add this code to a file. To update the table put the cursor on it and type C-u C-c C-c
On code blocks you can run using C-c C-c 

To run any Babel code you must enable the language. M-x customize-variable org-babel-load-languages and add python as well as any other supported languages you want to use.

{% highlight plaintext %}
-*- mode: org; org-confirm-babel-evaluate: nil; -*-
    
#+name: python_version
#+begin_src python :results value
import sys
info = sys.version_info
return(str(info.major) + "." + str(info.minor) + "." + str(info.micro))
#+end_src
    
    
| Language | Version |
|----------+---------|
| Python   |  2.7.10 |
  
#+TBLFM: $2='(sbe python_version)
{% endhighlight %}
