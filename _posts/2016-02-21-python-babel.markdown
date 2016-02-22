---
layout: post
title:  "Using Python in org-mode"
date:   2016-02-16 22:15:40 -1816
tags:
- blogs
- emacs
- babel
- python 
---

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
