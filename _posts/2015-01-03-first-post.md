---
layout: post
title: First Post!
tags: R
comments: true
---

This is the first post for my
[R](http://www.r-project.org/) + [knitr](http://yihui.name/knitr/) +
[jekyll](http://jekyllrb.com/) + [poole](https://github.com/poole/poole)
powered blog.


{% highlight r %}
print("Hello, world!")
{% endhighlight %}



{% highlight text %}
​[1] "Hello, world!"

{% endhighlight %}

Expect to see some more substantial content in the future!

## How It Works

I, like most other programmers, am incredibly lazy, and needed a way to author
a blog that was:

1. Stupidly easy to write for, and
2. Stupidly easy to deploy.

I'm using a combination of [jekyll](http://jekyllrb.com/), which is used to
generate the site itself; [poole](https://github.com/poole/poole) with the theme
[Lanyon](http://lanyon.getpoole.com/) to get a jump start with Jekyll (alongside
some very nice, responsive CSS), and a simple `make.R` script that converts
`.Rmd` posts into `.md` that can be served on GitHub pages, which is driven
mainly through the [knitr](http://yihui.name/knitr/) package.

The `R` script that powers this website is fairly simple -- we call 
`knitr::knit()`, with some knitr hooks + templating set up to support the
Jekyll-style markdown output. Check it out [here]({{ site.baseurl }}/make.R)!

Finally, I have a simple `Makefile` simply calls
`R --vanilla --slave -f make.R` to make the site. So, when I want to
write a new article, I can just:

1. Create a file `<date>-<title>` in `post/`,
2. Write something that may or may not be incredibly exciting to read,
3. Call `make` to update the site.

In fact, for 1., because (as I said before) I am a very lazy programmer,
so I also have a local `.Rprofile` for this project that gives me some
simple functions. In particular, I have a function `create_post()` for
creating a new post with some title, and the current date automatically
pre-pended to the post name.

Then [GitHub Pages](https://pages.github.com/) takes care of calling Jekyll
to produce the actual site to be served. Neat!

The icing on the cake -- by giving the project an (empty) `DESCRIPTION` file,
and telling [RStudio](http://www.rstudio.com/) that this is a
`Makefile`-managed project, I can also
rebuild the site right from RStudio with `Cmd + Shift + B`.
