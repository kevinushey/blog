---
layout: post
title: First Post!
tags: R
---

This is the first post for my R + knitr + jekyll + poole powered blog.


{% highlight r %}
print("Hello, world!")
{% endhighlight %}



{% highlight text %}
[1] "Hello, world!"
{% endhighlight %}

Expect to see some more substantial content in the future!

## How It Works

I, like most other programmers, am incredibly lazy, and needed a way to author
a blog that was:

1. Stupidly easy to write for, and
2. Stupidly easy to deploy.

I'm using a combination of [jekyll](http://jekyllrb.com/), which is used to
generate the site itself; [poole](https://github.com/poole/poole) with the theme
[Lanyon](http://lanyon.getpoole.com/), and a simple `make.R` script that converts
`.Rmd` posts into `.md` that can be served on GitHub pages.

The `R` script that powers this website is fairly simple -- we call 
`knitr::knit()`, with some knitr hooks + templating set up to support the
Jekyll-style markdown output:


{% highlight r %}
cat(readLines("make.R"), sep = "\n")
{% endhighlight %}



{% highlight text %}
library(knitr)

# Set some knit options
knitr::render_jekyll()

knitr::opts_chunk$set(
  fig.height = 5,
  fig.width = 7.5,
  out.extra = '',
  tidy = FALSE,
  comment = NA,
  results = 'markup'
)

knitr::opts_knit$set(root.dir = getwd())

# Knit all of the .Rmd documents in post
posts <- list.files("posts", full.names = TRUE)

# Ensure the '_posts' directory exists
if (!file.exists("_posts"))
  dir.create("_posts")

for (inputPath in posts) {

  fileName <- basename(inputPath)
  fileNameSansExtension <- tools::file_path_sans_ext(fileName)

  outputPath <- file.path(
    "_posts",
    paste(fileNameSansExtension, ".md", sep = '')
  )

  knitr::knit(
    input = inputPath,
    output = outputPath
  )

}
{% endhighlight %}

and the `Makefile` simply calls `make.R` to make the site. So, when I want to
write a new article, I can just:

1. Create a file `<date>-<title>` in `post/`,
2. Write something that may or may not be incredibly exciting to read,
3. Call `make` to update the site.

Neat!
