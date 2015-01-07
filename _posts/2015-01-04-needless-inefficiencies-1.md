---
layout: post
title: Needless Inefficiencies in R -- Head and Tail
tags: R
---



This is part one of an unboundedly large number of parts
investigating some of, what I'll call,
'needless inefficiencies' in `R`.

## Preamble -- Why I Love R

I like to think of `R` as one of the best programming
languages with one of the worst 'standard libraries' --
by that, I mean the set of functions exposed in the set of
'base' `R` packages, e.g. `base`, `tools` and `utils`. While
`R` comes with 'batteries included', to steal some lingo
from the Pythonistas of the world, the problem is that `R`
comes with a needlessly inconsistent, and often
unnecessarily slow set of, erm, 'batteries' for common
tasks.

At the same time, the `R` language itself is quite simple,
easy to read and understand, and provides many great
mechanisms for 'meta-programming', or manually constructing
and massaging calls, expressions, and whatever else you
might want to do (rightfully or wrongfully so). This allows
package authors to generate incredibly powerful interfaces,
probably most notably in the recently released
[dplyr](http://cran.r-project.org/web/packages/dplyr/index.html)
package. Given the small number of syntactical 'primitives'
in `R`, (well-written) and idiomatic `R` code can be very
readable, while still being quite performant.

Furthermore, the fact that [CRAN](http://cran.r-project.org/)
exists, and the community around `R` is so powerfully devoted to
constructing better tooling for making `R` more than just a
'programming language for statistics' means that we have
some excellent extensions and re-inventions of the 'standard
library'. Those familiar with the
[Hadley-verse](http://blog.datascienceretreat.com/)
probably know what I mean -- plenty of Hadley's packages
implement functionality already available in base `R`, but
these packages are far more cohesive, well-organized,
faster, and ultimately more useful.

Not to discount the efforts of R-Core or other package
authors -- the set of functions baked into `R` are
enormously useful (if often inconsistently named or
potentially awkward to use), and there are a gigantic number of
overall high quality packages available that extend
`R`'s functionality. However, there
are fewer packages that focus specifically on extending the
'standard library', or making `R` feel more like a
'first-class' programming language.

## Needless Inefficiencies

As `R` enters the public spotlight as more than 'just a 
programming language for statistics', programmers, rather
than just statisticians, are becoming interested in the
language itself, and are often surprised at what I'll call
the 'needless inefficiencies' in the GNU-R implementation.
Radford Neal's [pqR](http://www.pqr-project.org/) is
one of the most visible alternative implementations of `R`
that attempts to maintain a close adherence to the
`R` language 'specification', while providing many more
opportunities to tune performance wherever possible.
[His presentation at DSC](http://www.cs.utoronto.ca/~radford/ftp/pqR-dsc.pdf)
is a great overview of some of these problems and how they've
been tackled in `pqR`.

I'm going to focus on inefficiencies in the 'standard library'
specifically; that is, the set of `R` functions made available
by the `base` packages in an `R` session, especially those
implemented as pure `R` functions. And today I'll start by
bashing `head` and `tail`.

## Head and Tail Perform Unnecessary Allocations

Consider the (default S3 method) implementations of
`head` and `tail`:


{% highlight r %}
print(utils:::head.default)
{% endhighlight %}



{% highlight text %}
function (x, n = 6L, ...) 
{
    stopifnot(length(n) == 1L)
    n <- if (n < 0L) 
        max(length(x) + n, 0L)
    else min(n, length(x))
    x[seq_len(n)]
}
<bytecode: 0x7f931cb2c0d8>
<environment: namespace:utils>
{% endhighlight %}



{% highlight r %}
print(utils:::tail.default)
{% endhighlight %}



{% highlight text %}
function (x, n = 6L, ...) 
{
    stopifnot(length(n) == 1L)
    xlen <- length(x)
    n <- if (n < 0L) 
        max(xlen + n, 0L)
    else min(n, xlen)
    x[seq.int(to = xlen, length.out = n)]
}
<bytecode: 0x7f931f84db50>
<environment: namespace:utils>
{% endhighlight %}

Basically, the functions are implemented in terms of
'bounds check', plus a call to `x[seq(...)]`. Why is this
somewhat silly?

The issue I have here is simply that the `seq()` functions
will **allocate a new integer vector**, when really all
we need is a copy of a subset of the vector from some range.

We could produce a simple + faster implementation using
a little bit of `Rcpp`:


{% highlight cpp %}
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector head_cpp(NumericVector x, int n) {
  NumericVector output = no_init(n);
  std::copy(x.begin(), x.begin() + n, output.begin());
  return output;
}
{% endhighlight %}

Let's do a little microbenchmark:


{% highlight r %}
x <- rnorm(1E6)
n <- 5E5
library("microbenchmark")

identical(head(x, n), head_cpp(x, n))
{% endhighlight %}



{% highlight text %}
[1] TRUE
{% endhighlight %}



{% highlight r %}
microbenchmark(
  R = head(x, n),
  cpp = head_cpp(x, n)
)
{% endhighlight %}



{% highlight text %}
Unit: microseconds
 expr      min        lq     mean   median       uq      max neval cld
    R 2650.433 3334.1125 5923.547 4258.977 4835.156 42380.68   100   b
  cpp  366.095  909.3085 1962.349 1005.714 2482.595 38173.22   100  a 
{% endhighlight %}

This (somewhat overly simplified) implementation has
improved performance by roughly 4x. Why? Because we don't
perform the **needless allocation of an integer vector of
size 500 000**. That is, in the base-R implementation of
`head`, this call:


{% highlight r %}
x[seq_len(n)]
{% endhighlight %}

forces an allocation of an integer vector of `1:n` through
`seq_len` -- something which should be completely
unnecessary. Interestingly enough, `R` doesn't seem to have
any notion of subsetting with 'ranges', and so there is
no 'efficient' way (at the base R level) to subset a
range.

There is, actually, a hacky way of avoiding this overhead,
though -- we can call the `length<-` function, e.g.


{% highlight r %}
x <- 1:5
length(x) <- 3
x
{% endhighlight %}



{% highlight text %}
[1] 1 2 3
{% endhighlight %}

However, if we didn't want to modify `x` in place, we could
also call


{% highlight r %}
x <- 1:5
y <- `length<-`(x, 3)
x
{% endhighlight %}



{% highlight text %}
[1] 1 2 3 4 5
{% endhighlight %}



{% highlight r %}
y
{% endhighlight %}



{% highlight text %}
[1] 1 2 3
{% endhighlight %}

Is it actually faster?


{% highlight r %}
x <- rnorm(1E6)
n <- 5E5
microbenchmark(
  R = head(x, n),
  Cpp = head_cpp(x, n),
  len = `length<-`(x, n)
)
{% endhighlight %}



{% highlight text %}
Unit: microseconds
 expr      min       lq     mean   median       uq       max neval cld
    R 2674.635 3351.066 4896.215 4641.962 5518.070 45970.934   100   b
  Cpp  355.761  906.010 1352.968  973.765 1109.236  4358.272   100  a 
  len  496.054 1001.045 1445.843 1080.661 1294.058  4626.896   100  a 
{% endhighlight %}

Look at that -- basically on par with our `head_cpp`
function. In this case, we get this fancy behaviour
because `length<-` is a primitive function, and hence is
implemented in `C` and gets such 'range-based' subsetting
access to the vector. For the curious, the `length<-`
primitive is implemented as `do_lengthgets`. You can
[check out the implementation online](https://github.com/wch/r-source/blob/cf829c12299b8571cd67e9d8aae88ac31450c73c/src/main/builtin.c#L780-L875),
but I'll summarise it for you -- it's doing exactly what
we're doing, but handling all of the atomic `R` types
(not just numeric vectors), and also copying over the `names`
attribute if it exists. (It also allows you to 'extend'
a vector, and will pad the vector with `NA`s as necessary).

Sidenote: the main thing we miss out on from `head` is handling
of negative indices; e.g. it would be possible to chop off
the tail of a vector by providing a negative value to `n`.
Of course, this too would be trivial to implement in `C`
or `C++`.

This is what I mean by 'needless inefficiencies' in `R` --
there are plenty of hot spots in the 'standard library' that
deserve to be optimized, but simply aren't. That being said,
there are very good reasons why R-core is very conservative
about optimizing functions like these:

1. Backwards compatiblity + stability of the 'core' `R`
   implementation is the highest priority; extensions like
   these can (and often should) be implemented through
   packages, and
   
2. Optimizations like this can break old code in surprising
   ways -- there are likely bits in how attributes are
   preserved, or how other bits marked on the internal
   object itself, are massaged in the `head` implementation
   that are not completely obvious.

And, when all is said in done -- `head` and `tail` are going
to be fast enough 99.99% of the time, but one cannot help
but shed a single tear for the poor 0.01% of us who worry
about these wasteful allocations.

More fundamentally, it would be useful if `R` exposed a
primitive `subsequence()` function, upon which functions like
`head.default` and other range-based extraction
methods could be implemented. In other words, a primitive
like:


{% highlight cpp %}
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector subsequence(NumericVector x, int start, int end) {
  
  if (start > end)
    return NumericVector();
  
  // translate from R to C indexing
  --start;
  --end;
  
  // bounds checking
  if (start < 0) start = 0;
  if (end > x.size()) end = x.size();
  
  // note: want to be tail inclusive
  NumericVector output = no_init(end - start + 1);
  std::copy(x.begin() + start,
            x.begin() + end + 1,
            output.begin());
  
  return output;
            
}
{% endhighlight %}

which is then called as, e.g.


{% highlight r %}
head <- function(x, n = 6L)
  subsequence(x, 1L, n)

tail <- function(x, n = 6L)
  subsequence(x, length(x) - n, length(x))

x <- as.numeric(1:10)
head(x)
{% endhighlight %}



{% highlight text %}
[1] 1 2 3 4 5 6
{% endhighlight %}



{% highlight r %}
tail(x)
{% endhighlight %}



{% highlight text %}
[1]  4  5  6  7  8  9 10
{% endhighlight %}



{% highlight r %}
subsequence(x, 5, 8)
{% endhighlight %}



{% highlight text %}
[1] 5 6 7 8
{% endhighlight %}

As per usual -- one could easily implement this in a
package, but it would be nice if something like this were
made available in `R` itself.
