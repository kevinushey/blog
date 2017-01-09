---
layout   : post
title    : Parent Frames and Backwards Compatibility
tags     : r
comments : true
---

This post will be short and sweet -- I wanted to discuss one of the techniques I used for preserving backwards compatibility with some functions in [**sparklyr**](http://spark.rstudio.com/) whose signature had changed, using some tricks for accessing + modifying the 'parent frame' of a function.

The **sparklyr** package comes with a number of functions that interface with the [Spark machine learning API](https://spark.apache.org/docs/latest/ml-guide.html). An early incantation of the `ml_kmeans()` function had a signature like so (trimmed for readability):


{% highlight r %}
ml_kmeans <- function(x, max.iter, ...) {
  # call into Spark's kmeans implementation
}
{% endhighlight %}

However, this provided a bit of confusion -- the R function most users are familiar with, `stats::kmeans()`, uses `iter.max` as the argument name for specification of a maximum number of iterations, rather than `max.iter`. I wanted to unify the `ml_kmeans()` signature with the `stats::kmeans()` signature without breaking existing code, and I wanted to do this as lazily as possible, and without forcing myself to document a redundant argument.

I settled on this little bit of magic:


{% highlight r %}
ml_kmeans <- function(x, iter.max, ...) {
  ml_backwards_compatibility_api()
  # call into Spark's kmeans implementation
}
{% endhighlight %}

In other words, the call to `ml_backwards_compatibility_api()` should just magically 'fix up' calls of the form `ml_kmeans(x, max.iter = 100)`, such that they behave as though the user had called `ml_kmeans(x, iter.max = 100)`. How can one measily function call accomplish this?

There are three primary features of R that make this possible:

1. On execution, each function gets its own environment, where arguments + newly defined variables will live,

2. Functions can access the environments of their callers, using the `parent.frame()` function,

3. Named arguments in a function call not explicitly matched to a parameter will be coalesced into the `...` argument (when available).

Putting this together, let's see what our implementation of `ml_backwards_compatibility_api()` might look like:


{% highlight r %}
ml_backwards_compatibility_api <- function() {
  
  # access caller's environment
  envir <- parent.frame()
  
  # access '...' from caller's environment
  dots <- eval(quote(list(...)), envir = envir)
  
  # extract 'iter.max' from caller's environment
  iter.max <- envir$iter.max
  
  # extract 'max.iter' from dots of caller's environment
  max.iter <- dots$max.iter
  
  # if 'iter.max' was not supplied, but 'iter.max' was,
  # then overwrite 'iter.max' with the value of 'max.iter'
  if (is.null(iter.max) && !is.null(max.iter))
    assign("iter.max", max.iter, envir = envir)
}
{% endhighlight %}

Now, I can document the 'official' function signature using `iter.max`, but still support users who have written code using `max.iter` in future versions of **sparklyr**. Depending on how aggressive I want to be, I could deprecate the usage of `max.iter` in future versions of **sparklyr**, but now I can at least be confident that any users of **sparklyr** won't see their code suddenly break with an update to **sparklyr**.

We could, of course, have just implemented all this backwards-compatibility stuff inline at the start of the `ml_kmeans()` function as well. Why do I prefer this solution?

1. It minimizes pollution: rather than having multiple lines of code effectively unrelated to what `ml_kmeans()` does, we just have a single line of code calling a function that handles this for us behind the scenes;

2. This function can be re-used elsewhere. You could imagine that we might have other functions, e.g. `ml_linear_regression()`, that take a similarly-named `max.iter` argument. By dropping in this same function call, we get this unified backwards compatibility across all of our functions.

3. We can expand our `ml_backwards_compatibility_api()` function without fuss, and do so without requiring any changes in the functions where it is called (assuming, of course, we are disciplined on how we handle this non-standard evaluation!)

With R, the disciplined use of non-standard evaluation can lead to some very elegant solutions. As long as you're comfortable with the bit of extra magic, allowing certain functions to modify the parent frame makes it possible to provide backwards compatibility in an API in a very clean way.
