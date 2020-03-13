---
layout: post
title:  "Radix trees, Dash and Company mode"
date:   2018-10-24 00:00:00 -0000
tags: [emacs, functional-programming, radix-trees, company-mode, data-structures]
---

## Radix trees

In the [Emacs 26.1 release notes](https://www.gnu.org/software/emacs/news/NEWS.26.1) there's a reference to a new library:

_New Elisp data-structure library 'radix-tree'_

I checked and the radix-tree data structure does not yet appear in the info documentation, but there is of course documentation for each of the functions in the implementation `radix-tree.el`. In this post I'll show how to use radix trees, along with company mode (an auto complete library, the name comes from COMplete ANYthing), to implement a custom dictionary of words that you would like to be able to auto-complete when typing.

![Autocomplete](/../images/autocomplete.png)

The source code and dictionary used in this post can be found in this bitbucket [repo](https://bitbucket.org/justinhj/company-custom-dictionary/src/master/)

### What are radix trees?

Rather than go into the implementation and detailed explanation of Radix trees check them out on [Wikipedia](https://en.wikipedia.org/wiki/Radix_tree) or your favourite algorithms textbook . For the purposes of this post let's go with a super imprecise explanation. When you store a map of keys that are associated with some value there are a number of ways to represent that as a data structure. What Radix Trees offer is that when the key is a sequence of some kind (say a string of characters or a list of numbers) we can store the keys in a much abbreviated format, taking advantage of the shared prefixes amongst many keys. For example most Vancouver phone numbers begin with 778 or 604. Most of the numbers in a radix tree can be stored under one of those three digit prefixes rather than in three levels of tree (7,7,8...). If that's confusing never mind, it will become clear as we progress...

### Exploring radix trees in Emacs

A small example... say we want to store the following keys in a key value store: application, appetizer, applicative, apple.

To start with we need an empty radix tree, which is just defined as nil:

```emacs-lisp
(require 'radix-tree)

radix-tree-empty
```

You add key/values to the map like this:

```emacs-lisp
(setq tree-1 (radix-tree-insert radix-tree-empty "application" t))
;; (("application" . t))
```

 Note that inserting returns a new tree that contains just the single key "application". For the purposes of our program we don't need to store an actualy value, we're just interested in the keys which represent valid English words, so we just store `t' which is true in Emacs Lisp.

Next we'll make a new tree by inserting the next word into `tree-1':

```emacs-lisp
(setq tree-2 (radix-tree-insert tree-1 "appetizer" t))

;; (("app" ("lication" . t) ("etizer" . t)))
```

As you can see the radix tree split the key up into the shared prefixes between the two words. We can query how many words the tree has in total like this:

```emacs-lisp
(radix-tree-count tree-2)

;; 2 (#o2, #x2, ?\C-b)
```

### Reducing a list and the Dash list API

We've seen how to add elements one at a time to the tree, but our goal is to take a list of words and add them to a dictionary. For that we will need to use the `seq-reduce' function; a functional programming construct for reducing a sequence to a single value using some function that accumulates results:

```emacs-lisp
(seq-reduce (lambda (acc it) (radix-tree-insert acc it t)) '("application" "appetizer" "applicative" "apple") radix-tree-empty)

;; (("app" ("l" ("icati" ... ...) ("e" . t)) ("etizer" . t)))
```

In the output you can see that the four words have been neatly split into their shared and non-shared parts.

`seq-reduce` is fine for our purposes, but when working with Emacs lisp lists I prefer to use [Dash](https://github.com/magnars/dash.el) which is a package providing a more modern list API. All Dash functions begin with a dash hence the name. We can replace the code above using Dash as follows:

```emacs-lisp
(require 'dash)
(-reduce-from (lambda (tree word) (radix-tree-insert tree word t)) radix-tree-empty '("application" "appetizer" "applicative" "apple"))

;; (("app" ("l" ("icati" ... ...) ("e" . t)) ("etizer" . t)))
```

In English when you refer to a word used earlier in the conversation you will say "it" instead, and this is called anaphora. Dash provides "anaphoric" versions of many of its functions that begin with two dashes that let you abbreviate the lambda form we used above and refer to each item as it. In the case of the `--reduce-from` we get both it and acc (for the accumulated result):

```emacs-lisp
(--reduce-from (radix-tree-insert acc it t) radix-tree-empty '("application" "appetizer" "applicative" "apple"))

;; (("app" ("l" ("icati" ... ...) ("e" . t)) ("etizer" . t)))
```

That's nicer! Now we need a function that takes a sequence of words and adds them to a radix tree: 

```emacs-lisp

(defun list-to-radix-tree(l)
  (--reduce-from (radix-tree-insert acc it t) radix-tree-empty l))

(setq small (list-to-radix-tree '("application" "appetizer" "applicative" "apple")))

;; (("app" ("l" ("icati" ... ...) ("e" . t)) ("etizer" . t)))
```

### Reading words from a file and making a radix tree

Our next step is to load the words for our custom dictionary from a file. The one in the github repo `dictionary.txt` contains 172k words. We can load it and turn it into a list of words, and finally build a radix tree as follows:

```emacs-lisp

 (defun radix-tree-from-file(file-path)
   (-> 
    (with-temp-buffer
      (insert-file-contents-literally file-path)
      (buffer-substring-no-properties (point-min) (point-max)))
    split-string
    list-to-radix-tree))

 (radix-tree-from-file "dictionary.txt")

```

 Note the use of "->" which is a threading macro from Dash. It lets us put a list of operations together and "threads" the result from one step to the next, making things a bit easier to read. You'll see a similar operator in Clojure.

### Speeding it up

Hmm, that was kinda slow. When we start using the Company mode we need to load the file and we don't want a delay like that. Let's use the emacs benchmark facility to see just how slow it is:

```emacs-lisp

(require 'benchmark)
(benchmark-elapse (radix-tree-from-file "dictionary.txt"))

;; 6.021951

```

Six seconds is a bit too much. How about we just write the radix tree to a file instead, then load that? First we need to write the tree to a string using `print1-to-string`, then we can stick that in a buffer and write it to a file.

```emacs-lisp

 (defun write-text-to-file(text file-path)
   (save-excursion
     (let ((buffer (find-file file-path)))
       (switch-to-buffer buffer)
       (erase-buffer)
       (insert text)
       (save-buffer)
       (kill-buffer))))

 (setq dictionary (radix-tree-from-file "dictionary.txt"))

 (write-text-to-file (prin1-to-string dictionary) "dictionary.el")

 ;; (write-text-to-file (prin1-to-string small) "dictionary.el")

```

Now let's see how much faster it is to simply load the data structure rather than build it:

```emacs-lisp

 (defun tree-from-file(file-path)
   (save-excursion 
     (let* ((buffer (find-file file-path))
            (tree (read buffer)))
       (kill-buffer buffer)
       tree)))

 (benchmark-elapse
   (progn
     (setq loaded-dictionary (tree-from-file "dictionary.el"))
     t))

 ;; 0.198365

```

Great! The first time we run the program it will take 6 seconds to build, but subsequently we can load the radix tree data from disk which takes 0.2 seconds. That means if we prepare the `dictionary.el` file we can simply load that when the system starts without a noticable slowdown. The next step is to be able to find all the keys given a prefix. `radix-tree-subtree` does the job, returning a subtree rooted at the given prefix. Given the relevant subtree we can then iterate all of the keys and values using the function `radix-tree-iter-mappings`. Here we use the destructive `!cons` (also from Dash) to build up a list of all the keys, which we then return. This is now all the functionality we need to return for our auto-complete functionality:

```emacs-lisp

 (defun radix-tree-keys(subtree prefix)
   (let (keys '())
     (radix-tree-iter-mappings (radix-tree-subtree subtree prefix)
			       (lambda (key val)
				 (!cons (concat prefix key) keys)))
     keys))

 (radix-tree-keys loaded-dictionary "antidi")

 ;; ("antidiscrimination" "antidilution" "antidiarrheal" "antidiabetic")

```

## Company Mode

[Company Mode](http://company-mode.github.io) is one of the two most popular completion frameworks for emacs (the other being [Auto-Complete](https://github.com/auto-complete/auto-complete)). In order to make our own custom dictionary auto completion we just need to implement a single function to implement a "backend".

The best documentation for how to write a backend is in the docstring for `company-backends' so I'd recommend reading that in full to see the capabilities of Company mode.

First, the code, I'll explain each part below:

`C-h v company-backends`

```emacs-lisp

(require 'company)

(defun get-candidates (prefix)
  "Given a prefix return a list of matching words that begin with it"
  (when (> (length prefix) 2)
    (radix-tree-keys company-custom-dictionary--words-tree (downcase prefix))))

(defun company-custom-dictionary (command &optional arg &rest ignored)
  "Company mode backend for a custom dictionary stored as a radix tree."
  (case command
    ('init    
     (unless (boundp 'company-custom-dictionary--words-tree)
         (setq company-custom-dictionary--words-tree (tree-from-file "dictionary.el"))))
    ('prefix
     (company-grab-word))
    ('candidates
     (radix-tree-keys company-custom-dictionary--words-tree (downcase arg)))
    ('ignore-case
     'keep-prefix)))
    
;; (provide 'company-custom-dictionary) 

;; Push the mode to the list of company backends
(push 'company-custom-dictionary company-backends)

;; If you want to change the dictionary, rewrite dictionary.el and unintern the symbol
;; (unintern 'company-custom-dictionary--words-tree)

```

The few lines above are, believe it or not, all you need to make our custom dictionary backend work! We are just making a callback which implements the Company mode API by sending us commands for us to handle. Let's look at each one:

- `init` Init is called when company mode is initially enabled. This could be when emacs loads, or if you enable manually it will be called whenever you enable it. It could be called multiple times in a session so keep that in mind when implementing. In this case our implementation checks whether we loaded the dictionary or not. If we did then nothing happens, otherwise we load it.
- `prefix` - This is the text the user has typed so far that we want to complete. I call the built in function `company-grab-word` which does what you'd expect in most cases. You can write your own depending on your needs. I also check if there are any potential candidates. If not we should return nil that enables other company backends further on in the list to try and match.
- `candidates` - We are given `arg` which contains the word to be completed and must return the list of candidates that will show up in the menu for the user to pick from. We simply use radix-tree-keys to get the list of words based on the prefix. Note that we make the completion to lower case as we want to match words ignoring that the user may have capitalized the word.
- `ignore-case` - We return a special response `keep-prefix' which maintains the users original capitalization.

Note that we don't want the performance penalty of returning the entire dictionary when matching an empty string, or a couple of characters, so the function `get-candidates` handles only words greater than 3 in length.

## A note on case matching

In this example I wanted the user dictionary to use only lower case letters. Capitalization is up to then up to the user; if you want to capitalize a word you can do so and it will match correctly. If instead you want a dictionary where case is important (perhaps function calls in a camel case API) you can set `ignore-case` to `nil` and remove the call to `downcase` when generating the candidates.

# Final notes

So that's all folks! This is a fairly simple auto complete mode, but you can easily modify the code to come up with your own based on your needs. For example: 

- Common mispelled words list (Do you have trouble with necessary or disappoint? Add all your most hated words to the list)
- Domain words. Do you work in a domain with specialist terminology not in a dictionary?
- Phone numbers, server names, IP addresses and so on

# Corrections

Thanks to Reddit user MCHerb for pointing out a couple of things including a typo which have been corrected in this update, and Herbert Jones for noticing and fixing a potential bug with matching words not in the dictionary. See the comments below for more.
