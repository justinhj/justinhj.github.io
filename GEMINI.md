# Justin's technical blog Function[Justin]
## Where the main layout is defined
When editing the main layout look in _layouts/

## Testing changes
The user will have the site constantly rebuilding using the Jekyll server command so you don't have to run it it.
You can use the playwright tool to view the site in the browser to answer the users questions and verify your changes.
If the site is not running it may be because there is an error, ask the user to copy the error for you.
The site runs on localhost port 4003.

## Bugs and improvements
No active bugs.

## CSS Organization

The primary CSS for this Jekyll site is managed through Sass.

- **Main Sass File:** The main entry point for the site's CSS is `/css/main.scss`. This file contains variable definitions and imports the other Sass partials.

- **Sass Partials:** The `_sass` directory contains the individual Sass partials, which are organized by component (e.g., `_header.scss`, `_footer.scss`, `_layout.scss`). These files are imported into `main.scss`.

One of the key files to edit to change appearance is _sass/_base.scss, which contains the base styles for the site.

- **Org Mode CSS:** The `_orgcss/site.css` file contains styles specifically for content that has been generated from Org mode files.

- **Editing CSS:** To edit the site's CSS, you should modify the appropriate `.scss` file in the `_sass` directory and then recompile the Jekyll site. Changes to `main.scss` will also require a recompilation. The `_orgcss/site.css` file can be edited directly.

- **Jekyll Configuration:** The `_config.yml` file includes the `css` and `_orgcss` directories in the site build, ensuring that the compiled CSS is available to the site.

## Site Structure

This Jekyll site follows the standard Jekyll directory structure.

*   `_config.yml`: Stores site-wide configuration data.
*   `_posts`: Contains blog posts, which must be named with the `YEAR-MONTH-DAY-title.MARKUP` format.
*   `_includes`: Contains reusable elements like partials.
*   `_layouts`: Contains the main templates for the site.
*   `_site`: The output directory where the generated site is placed.
*   `_data`: For site data.
*   `_drafts`: For unpublished posts.
*   `_sass`: For Sass partials.
*   `css`: Contains the main `main.scss` file.
*   `_orgcss`: Contains CSS for Org mode generated files.
*   `assets` or other directories: Jekyll will also copy over any other directories you create to the generated site.

## Creating a new post

This section details how to create a hello world post for a new post that you will work on interactively with the user.

First you must get the current date as it is needed for creating the post. You can ask the user if they want to date the post as today or as a future date. Agree with the user at this point what the title of the post should be.

Posts start as an org file so create an org file following the naming scheme:

./org/posts/2020-03-09-how-to-blog-with-org-mode.org

Next add the front matter:

#+TITLE: Blogging with Emacs and Org-mode
#+AUTHOR: Justin Heyes-Jones
#+DATE: 2020
#+STARTUP: showall
#+OPTIONS: toc:nil
#+CREATOR: <a href="https://www.gnu.org/software/emacs/">Emacs</a> 26.3 (<a href="http://orgmode.org">Org</a> mode 9.4)
#+BEGIN_EXPORT html
---
layout: post
title: Blogging with Emacs and Org-mode
tags: [emacs, org-mode, blogging, github-pages, jekyll, popular]
---
<link rel="stylesheet" type="text/css" href="../../../_orgcss/site.css" />
#+END_EXPORT

You can consult the example post to see how to do headings, images and code blocks. We will use those techniques typically in new posts.

See the tags section below on how to do tags.

Note that at any point you can use the #+BEGIN_EXPORT html and #+END_EXPORT syntax to add arbitrarily complex interactive html content such as graphs.

Typically when creating a new post the user will ask you to do the above as well as make a sample framework of just the headings for each section with some sample latin text as a placeholder in each.

## Publishing and testing

Usually the testing flow is like this:

The user is running the server locally on port 4003. You can therefore use web tools to look at and interact with the post to help fix issues and check for layout or other problems.

When org mode files change they need to be exported to html so they appear in the blog. You can do that as follows:


``` bash
emacs --batch --load org/publish.el --eval (org-publish "all")
```

If this fails for any reason you can let the user know. emacs may not be available in which case they need to install it or perhaps just alias it to the GUI version

Example: alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs"

Checking for errors:
 1. Exit Code: In batch mode, Emacs will exit with a non-zero status if an unhandled error occurs. You can check this in
    your shell immediately after running the command:
       echo $?
 2. Standard Output/Error: All messages (from (message ...) or errors) will be printed directly to your terminal. If
    org-publish fails, the error message and potentially a backtrace will appear there.
 3. Logging: If you want to capture the output to a file for later inspection:

       emacs --batch --load org/publish.el --eval '(org-publish "all")' > publish.log 2>&1

## Tags

Making new tags is mechanical. You create a file in the _my_tags folder named tag.md where tag is the name of the tag.
Multiple word tags are broken up by dashes.

Every tag file contains the name of the tag in lower case (the slug) and in mixed human readable capitalization (name).

An example: 

```
---
layout: blog_by_tag
slug: ai
name: Ai
---
```

When the user asks you to make the tags for a post first consider what the post is about, then consider which existing tags match, finally make a new tag if the topic is entirely new.


