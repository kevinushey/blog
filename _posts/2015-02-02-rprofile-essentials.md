---
layout   : post
title    : RProfile Essentials
tags     : r
comments : true
---

If there's something programmers love, it's dotfiles.
A rather nice trend on GitHub has been for users to
include their
[dotfiles on a public repo](https://github.com/search?utf8=q=dotfiles)
(a great idea if you want to make your personal
configuration available across multiple systems --
just `git clone` and apply!), and it's a somewhat fun
archaeological exercise to trawl through the various
dotfile repositories to see how people have customized
their tools to their liking. (For the record, my
dotfiles and others [live here](https://github.com/kevinushey/etc).)

For the `R` programmer, the user dotfile typically lives
in `~/.Rprofile` -- this file gets `source()`-ed by
`R` upon startup, thereby making your own `R` tools
(that aren't worth putting into a package) available
in your session. I'm going to divulge some of the
essential bits of my own
[.Rprofile](https://github.com/kevinushey/etc/blob/master/R/.Rprofile).

## tl;dr

If you're short on time, just trust me and put
this in your `.Rprofile`. Otherwise, read on for
motiation.


{% highlight r %}
# warn on partial matches
options(warnPartialMatchAttr = TRUE,
        warnPartialMatchDollar = TRUE,
        warnPartialMatchArgs = TRUE)

# enable autocompletions for package names in
# `require()`, `library()`
utils::rc.settings(ipck = TRUE)

# warnings are errors
options(warn = 2)

# fancy quotes are annoying and lead to
# 'copy + paste' bugs / frustrations
options(useFancyQuotes = FALSE)
{% endhighlight %}

## Essential Pieces

These are things that I believe should exist in every
`~/.Rprofile`; or, in other words, wish were default
behaviour in `R`.

- `utils::rc.settings(ipck = TRUE)`: Auto-complete
  package names in `require()` and `library()` calls.

`R` actually provides a mechanism for you to configure
how many different types of autocompletions it provides
for you. This is all hidden within `rc.settings()`, and
you can see the various options available in the
(surprisingly well written) `?rc.settings` help page.
I'm not exactly sure why this option is disabled by
default; perhaps to avoid issues that users with slow
network drives might have? It certainly is useful when
you're trying to load certainly long named
[BioConductor packages](http://master.bioconductor.org/packages/release/data/annotation/html/BSgenome.Hsapiens.UCSC.hg19.html)...

- `options(warnPartialMatchAttr = TRUE)`: Warn on
  partial matching for the `attr()` function.

One thing that is really quite ... scary, is that `R`
allows for partial matching in a number of places. This
hallmarks the tension `R` has between an interactive
statistical environment (where every keystroke depletes
some cognitive energy you would rather expend on your
current problem), and `R` as a programming language
(where you would prefer that your programs be robust
and work both now _and_ in the future, with new data
and new parameters).

In general, I view this as a problem that auto-completion,
_not_ partial matching, should solve. But the
fact that this code works without warnings by default
is kind of terrifying:


{% highlight r %}
x <- ""
attr(x, "SomeVariable") <- 1
attr(x, "Some")
{% endhighlight %}



{% highlight text %}
​[1] 1

{% endhighlight %}

Thankfuly, it's possible to change this behaviour -- it
just seems a shame that this is not the default. Note
that if there are _multiple_ prefix matches, `R`
pretends that neither of them exist (and doesn't give
you any warning, regardless):


{% highlight r %}
attr(x, "SomeOtherVariable") <- 2
attr(x, "Some")
{% endhighlight %}



{% highlight text %}
​NULL

{% endhighlight %}

So you can imagine the insidious kinds of bugs that
could leak in if you actually _relied_ on partial
matching in your code. By the way -- there's a special
place in the
[`R Inferno`](http://www.burns-stat.com/documents/books/the-r-inferno/)
for those of you that do.

- `options(warnPartialMatchDollar = TRUE)`: Warn on
  partial matches for the `$` operator.
  
Same as above -- `$` performs partial matching by
default; I'd rather `R` give me a warning.

- `options(warnPartialMatchArgs = TRUE)`: Warn on
  partial matches for function argument names.
  
Yet again! All this partial matching gives me the
heeby-jeebies. If only there a way we could make these
errors...

- `options(warn = 2)`: Turn warnings into errors.

This is good practice to follow if you want to really
write robust `R` code. Warnings are printed for a reason,
and ignoring them is almost never the right response.
If you _really_ want to ignore a warning, you should
silence the noisy function explcitily,
with `suppressWarnings()`,
and provide a nice big comment above why this was the
correct solution.

- `options(useFancyQuotes = FALSE)`: Turn off fancy
quotes.

I've seen a few novice programmers get frustrated
because a path they copied from an `R` error message
just wasn't working -- and it was because that path
was printed and surrounded with fancy quotes, rather
than just the regular quotes.

### Nice-to-Haves

These ones are less essential, but I think are pretty
darn useful to have. Firstly, if you haven't done this
already, you should prefer putting every object you
create in your `.Rprofile` within its own environment,
and then attaching that environment to the search path,
like so:


{% highlight r %}
.__Rprofile_env__. <- new.env(parent = emptyenv())

## ... fill .__Rprofile_env__. with stuff ...

attach(.__Rprofile_env__.)
{% endhighlight %}

Side note: I would say that this is one of the very
few legitimate uses of `attach()`, but you should still
make sure that anything you place in that environment
is unlikely to mask functions in the packages you load.

With that, let's start filling our environment with
some goodies!

### Quickly Edit your .Rprofile

A nice little trick for quickly opening your
`~/.Rprofile` directly from `R` in your favorite
editor:


{% highlight r %}
### Use '.Rprofile' to quickly open your ~/.Rprofile

# Create an empty string with class '__Rprofile__'
# and assign it to our .__Rprofile.env__.
#
# Here, `class<-`() is just a sneaky way of creating
# an object with some class all in one expression.
assign(".Rprofile",
       `class<-`('', "__Rprofile__"),
       envir = .__Rprofile.env__.)

# Assign a print for the "__Rprofile__" class in that
# same environment. By printing the `.Rprofile` object,
# we actually go and edit it!
assign("print.__Rprofile__",
       function(x) file.edit("~/.Rprofile"),
       envir = .__Rprofile.env__.)
{% endhighlight %}
  
This one is nice for when you discover something new
and decide that it just must live in your `.Rprofile`.
So, you type `.Rpr<TAB>`, hit enter, the 'print'
method is invoked (calling `file.edit()`) and bam! You're
editing your `.Rprofile`. Neat trick, huh?

You can further (ab)use this to also make your `R`
session 'feel' like a shell. For example:


{% highlight r %}
pwd <- ""
class(pwd) <- "__pwd__"
print.__pwd__ <- function(x, ...) print(getwd())
pwd
{% endhighlight %}



{% highlight text %}
​[1] ""
attr(,"class")
[1] "__pwd__"

{% endhighlight %}

And now you know how to call functions without actually
using the `()` symbols. Fun times!

### Set Devtools Default Options

Are you a package author? Do you want to be? Either way,
you almost definitely want to be using
[`devtools`](https://github.com/hadley/devtools) to
help you along the way. Once you get into the groove
of collecting common functionality into different
packages, you want to be able to generate new projects
with a particular template quickly and efficiently.

You can use `devtools::create()` alongside some options
set in your `.Rprofile` to automate this. For example,
I have:


{% highlight r %}
options("devtools.desc" = list(
  Author = <name>,
  Maintainer = paste0(<name>, " <", <email>, ">"),
  License = "MIT + file LICENSE",
  Version = "0.0.1"
))
options("devtools.name" = <name>)
{% endhighlight %}

which ensures that any new packages I create with
`devtools::create()` are automatically set up with
everything I need.

### Print Library Paths on Startup

I find this one somehow reassuring -- I know where `R`
will be looking for packages when I start my `R`
session. Basically, we pretty-print the `.libPaths()`
variable:


{% highlight r %}
if (length(.libPaths()) > 1) {
  msg <- "Using libraries at paths:\n"
} else {
  msg <- "Using library at path:\n"
}
libs <- paste("-", .libPaths(), collapse = "\n")
message(msg, libs, sep = "")
{% endhighlight %}

### Don't Let R Blow Up your Console

Did you really want to see all 10000 elements of that
`list`? Probably not, right? Use:


{% highlight r %}
options(max.print = 100)
{% endhighlight %}

to tune it down a bit.

### Ending Remarks

A last word on your `~/.Rprofile` -- do not put anything
in there that can modify the result in execution of
others `R` code! As much as `stringsAsFactors = TRUE`
is the worst default ever, putting
`options(stringsAsFactors = FALSE)` is an even worse
idea -- because now the code you write is only
executable by others who have also opted in to this
option. Just bite the bullet and remember to use
`stringsAsFactors = FALSE` whenever necessary.

For most cases, I think any `R` code more than a
couple lines deserves to live in a package. If it's
useful, other people deserve to be able to stumble
upon it and easily use it too. And, if you decide
to place some code in your `~/.Rprofile`, make sure
it's exclusively for interactive use -- if the code
you write depends on your `.Rprofile`, that's a very
bad sign.

In my case, I collect these in a package
[`Kmisc`](https://github.com/kevinushey/Kmisc) (which
has unfortunately languished a bit recently), but it
does have some nice utilities for interactive use.
My personal favourite is `Kmisc::cat.cb()`, which lets
you write an `R` object to the clipboard, -- very
useful if you want to copy and paste output from an
object to somewhere else. The companion function,
`Kmisc::scan.cb()`, reads data from the clipboard and
into an `R` object -- also quite handy for quick
one-offs.

Finally, if you haven't already, I highly encourage you to:

  1. Create your own `~/.Rprofile`,
  2. Put it in a public repository,
  3. Start collecting your own little bits of
     productivity helpers to save you precious seconds
     each day. They add up!

