---
layout: post
title: Needless Inefficiences -- [.data.frame is a mess
tag:
---

## Needless Inefficiencies

Welcome back! [Last post]({{ site.baseurl }}/2015/01/04/needless-inefficiences-1/),
I looked at `head.default` and `tail.default`, and gave them
a little bit of a hard time, but ultimately there's nothing
seriously wrong with their implementations. Today, we get to
have a lot more fun. Fasten your seatbelts, because this will
be a bumpy ride.

The usual preamble: `[.data.frame` is very useful, nice and
terse, and 'makes sense' once you adopt the `R` mindset.
Get rows with `df[x, ]`, get column(s?) with `df[, x]`, or
get columns with just plain old `df[x]` (well, as long as
your `data.frame` isn't secretly a [`data.table`](http://cran.r-project.org/web/packages/data.table/index.html),
which supplies `[.data.table` as an incredibly powerful and
yet equally weird function.)

Intuitively, `[.data.frame` seems like it shouldn't be too
hard to implement. For the numeric types, we're trying to
get rows or columns by index; for logical types, we get the
rows or columns for which the vector elements are `TRUE`;
for character vetors, we match on `names` or `row.names`.
In addition, `data.frame`s should only contain atomic
vectors -- it is possible to stuff other objects in, but
that is usually quite rare and prone to break in other,
surprising, ways, and so is generally discouraged.
Seems like there isn't that much room for ugliness, right?

We'll start with one bit that is really subtle. We'll call
the subsetting indices as `df[i, j]`; that is, `i` denotes
a vector used for row subsetting, while `j` denotes a vector
used for column subsetting. Why is it
that the following two statements can give different results?


{% highlight r %}
df[x, ]
df[x]
{% endhighlight %}

In the first case, we are **explicitly** setting the `j` argument
to be missing; in the second case, it is **implicitly** missing.
It seems surprising, but `[.data.frame` does an ad-hoc dispatch
based on the number of implicitly missing arguments!

Can we use the `missing()` function to help us out here?


{% highlight r %}
f <- function(i, j) cbind(missing(i), missing(j))
rbind(
  f(1),
  f(1,)
)
{% endhighlight %}



{% highlight text %}
      [,1] [,2]
[1,] FALSE TRUE
[2,] FALSE TRUE
{% endhighlight %}

Well, that's not helpful -- `R` still believes that the `j`
argument is missing (which it is). But how do we differentiate
between this notion of **implicit** and **explicit** missingness?

Let's look at the first few lines of `[.data.frame` to find
out what really happens behind the scenes.


{% highlight r %}
function (x, i, j, drop = if (missing(i)) TRUE else length(cols) == 
    1) 
{
    mdrop <- missing(drop)
    Narg <- nargs() - (!mdrop)
    has.j <- !missing(j)
    if (!all(names(sys.call()) %in% c("", "drop")) && !isS4(x)) 
        warning("named arguments other than 'drop' are discouraged")
    if (Narg < 3L) {
      < ... snip ... >
{% endhighlight %}

This is made more complicated by the presence of the `drop`
argument, so try to ignore that bit. What `R` actually does
is 'dispatches' based on the number of args. Let's see:
    

{% highlight r %}
f <- function(x, y) nargs()
rbind(f(),
      f(1),
      f(1,),
      f(,))
{% endhighlight %}



{% highlight text %}
     [,1]
[1,]    0
[2,]    1
[3,]    2
[4,]    2
{% endhighlight %}

In other words, `nargs()` does not include
**implicitly missing** arguments when it counts the number
of arguments passed to the function.
Notice that `nargs()` in `f()` returns zero
(all arguments are implicitly missing), while `nargs()` in
`f(,)` returns two (all arguments are explicitly missing;
it's as though we had really called `f(<missing>, <missing>)`).

Okay, so we understand how `[.data.frame` can discriminate
between `df[i]` and `df[i, ]`, because `nargs()` gives us
a funny way to poke at that. Now, let's look at the first
branch, where `Nargs < 3` -- implying a `df[i]` call. 
I'll write my own comments above the code used for
`[.data.frame`, explaining what's going on each step of
the way.


{% highlight r %}
## This check implies the call is of the form `df[i]` or
## `df[i, drop = .`, so we want to do some kind of column
## subsetting.
if (Narg < 3L) {
  
  ## Ignore 'drop' -- when doing single-element subsetting,
  ## we always return a data.frame
  if (!mdrop) 
    warning("'drop' argument will be ignored")
  
  ## If there was no `i` argument, implying a call like
  ## `df[]`, just return `df`.
  if (missing(i)) 
    return(x)
  
  ## If `i` is a matrix, convert `x` to a matrix (!?) and then
  ## subset that matrix with `i`. I still do not understand
  ## matrix subsetting of data.frames (or matrix subsetting
  ## of matrices, for that matter...)
  if (is.matrix(i)) 
    return(as.matrix(x)[i])
  
  ## Get the names, and ensure it's a character vector
  nm <- names(x)
  if (is.null(nm)) 
    nm <- character()
  
  ## If i is not a character (ie, numeric or logical
  ## subsetting...), AND one (or more) of the names is NA...
  if (!is.character(i) && anyNA(nm)) {
    
    ## Replace the names with indices (1 to ncol(x))
    names(nm) <- names(x) <- seq_along(x)
    
    ## Call the next method after `[.data.frame`. In this
    ## case, that implies calling an internal generic; this
    ## effectively amounts to calling `as.list(x)[i]`, but
    ## this gets done in internal C code (there is no 
    ## `[.list` S3 method registered). This is the joy of
    ## 'internal generics'!
    y <- NextMethod("[")
    
    ## Get and validate the names
    cols <- names(y)
    if (anyNA(cols)) 
      stop("undefined columns selected")
    cols <- names(y) <- nm[cols]
  }
  else {
    
    ## Effectively the same as above, expect with marginally
    ## different error checks. Seems like this could have
    ## been consolidated...
    y <- NextMethod("[")
    cols <- names(y)
    if (!is.null(cols) && anyNA(cols)) 
      stop("undefined columns selected")
  }
  
  ## Fix up column names
  if (anyDuplicated(cols)) 
    names(y) <- make.unique(cols)
  
  ## Set 'automatic', 'compressed' row names, and the
  ## class for our return.
  attr(y, "row.names") <- .row_names_info(x, 0L)
  attr(y, "class") <- oldClass(x)
  return(y)
}
{% endhighlight %}

Although the dispatch was somewhat awkward, this mostly
seems sane. There is a bit of code duplication and weirdness
through calling `NextMethod("[")`, but it remains
functional and understandable. Although terribly opaque,
`NextMethod("[")` is the only way to get at that subsetting
primitive past `[.data.frame` (as `[.list` does not exist).

Let's move on! The next branch focuses on what happens if
`i`, our row subetting bit, is missing:


{% highlight r %}
## If `i` is missing, e.g. in x[, j]...
if (missing(i)) {
  
  ## For some reason, we provide a shortcut for when:
  ##
  ##   1. drop is TRUE,
  ##   2. j is missing, and
  ##   3. x is a one-column data.frame.
  ##
  ## This amounts to being a funky way of extracting the
  ## first column from a single column data.frame, but it
  ## seems odd to specialze for that case ...
  if (drop && !has.j && length(x) == 1L) 
      return(.subset2(x, 1L))
  
  ## Get names as non-null character vector.
  nm <- names(x)
  if (is.null(nm)) 
      nm <- character()
  
  ## Do some more weirdness, similar to before, where we
  ## inline some awkward error handling over what is really
  ## just a call to `.subset(x, j)`.
  if (has.j && !is.character(j) && anyNA(nm)) {
      names(nm) <- names(x) <- seq_along(x)
      y <- .subset(x, j)
      cols <- names(y)
      if (anyNA(cols)) 
          stop("undefined columns selected")
      cols <- names(y) <- nm[cols]
  }
  else {
      y <- if (has.j) 
          .subset(x, j)
      else x
      cols <- names(y)
      if (anyNA(cols)) 
          stop("undefined columns selected")
  }
  
  ## If, after subsetting, we have a single-column
  ## data.frame then do another awkward early return.
  if (drop && length(y) == 1L) 
      return(.subset2(y, 1L))
  
  ## Fix up names.
  if (anyDuplicated(cols)) 
      names(y) <- make.unique(cols)
  
  ## Get the number of rows. Wait, why are we using
  ## .row_names_info instead of just plain `nrow`? If you
  ## look at how `nrow()` works for a `data.frame`, you'll
  ## see...
  ##
  ##    nrow() 
  ##        -> dim() 
  ##        -> dim.data.frame()
  ##        -> .row_names_info(, 2L)
  ##
  ## so it is just a shortcut to that dispatch.
  nrow <- .row_names_info(x, 2L)
  
  ## For one-row data.frames, if drop is TRUE, try to
  ## return the row as a vector, letting structure handle
  ## coercion. Yuck!
  if (drop && !mdrop && nrow == 1L) 
      return(structure(y, class = NULL, row.names = NULL))
  
  ## Otherwise, set the class, row.names, and return.
  else {
      attr(y, "class") <- oldClass(x)
      attr(y, "row.names") <- .row_names_info(x, 0L)
      return(y)
  }
}
{% endhighlight %}

Phew! We've now seen the dispatches for:

1. `df[i]`; ie, column subsetting, and
2. `df[, j]`, ie, column subsetting with `i` missing.

Now let's get to the _really_ fun stuff. Now, we need to
see how row subsetting, and potentially column subsetting,
gets performed.


{% highlight r %}
## Let's make a copy of 'x' and call it 'xx', because
## we're going to start mutating that object.
xx <- x
cols <- names(xx)

## Replace x with a list of length x, containing the
## same attributes of `xx`. Really, this copies _all_
## attributes from `xx` to `x`.
x <- vector("list", length(x))
x <- .Internal(copyDFattr(xx, x))

## And then, now that we've copied all of the attributes,
## let's go ahead and clear out the data.frame specific
## ones, because ... I guess we need to refresh them later?
oldClass(x) <- attr(x, "row.names") <- NULL

## If `j` was specified (ie, this is `df[i, j]`)...
if (has.j) {
  
  ## Get names as character
  nm <- names(x)
  if (is.null(nm)) 
    nm <- character()
  
  ## If any names are NA, reset the names as integers
  if (!is.character(j) && anyNA(nm)) 
    names(nm) <- names(x) <- seq_along(x)
  
  ## Oh! Now you know! We removed the class from `x` so
  ## that we could use `[`, and get back at that `[.list`
  ## primitive hiding in the C sources. So this is where
  ## we do column subsetting. This is still weird as heck
  ## though, since we're subsetting an _empty list_; ie,
  ## list whose elements are just NULL. I guess this is
  ## a way of getting the names of x in an appropriate order?
  x <- x[j]
  
  ## Some more unreadable nonsense handling the special
  ## case of drop being true, and `x` being a length
  ## one vector.
  cols <- names(x)
  if (drop && length(x) == 1L) {
    
    ## Note that, within this branch, we no longer care what
    ## `x` is. So we just used that as some weird proxy
    ## subsetting object; now we go back to `xx` (which
    ## is the orginal `x` -- remmber how we copied it?
    ## Why on earth is this code so convoluted?)
    if (is.character(i)) {
      rows <- attr(xx, "row.names")
      i <- pmatch(i, rows, duplicates.ok = TRUE)
    }
    xj <- .subset2(.subset(xx, j), 1L)
    return(if (length(dim(xj)) != 2L) xj[i] else xj[i, 
                                                    , drop = FALSE])
  }
  
  ## More error checking + 'fixing up' of names and such.
  if (anyNA(cols)) 
    stop("undefined columns selected")
  if (!is.null(names(nm))) 
    cols <- names(x) <- nm[cols]
  
  ## Get some index vectors, so that we can handle the
  ## column re-organizing / subsetting later.
  nxx <- structure(seq_along(xx), names = names(xx))
  
  ## This vector governs the column indices, which we
  ## will see are used later when copying from `xx`
  ## back into `x`.
  sxx <- match(nxx[j], seq_along(xx))
}

## When `j` is not supplied, this implies we want all
## columns without re-ordering -- so just take the indices
## from 1 to length(x).
else sxx <- seq_along(x)

## Okay, now let's look at row subsetting.
rows <- NULL

## If `i` is a character vector, figure out the indices by
## matching `i` to the row.names of `xx`. (Not `x` --
## remember, we decided to turn that into a `list` to get
## at the `[` primitive)
if (is.character(i)) {
  
  ## Directly access the attribute, to avoid dispatch /
  ## other ugliness in `rownames()`, or `row.names()`.
  rows <- attr(xx, "row.names")
  i <- pmatch(i, rows, duplicates.ok = TRUE)
}

## For each vector in `x`, our empty list...
for (j in seq_along(x)) {
  
  ## Figure out the vector in `xx` that we want to put at
  ## the `j`th column.
  xj <- xx[[sxx[j]]]
  
  ## If xj is not a 2D object (e.g. a matrix), then just
  ## mash it into x[[j]] (subsetting with `i` -- there's
  ## the row subsetting kicking in!) Also, implicitly
  ## respect the `drop` attribute here.
  ##
  ## Note that we're now populating `x`, our 'output'
  ## data.frame, with elements of `xx`. So very roundabout!
  if (length(dim(xj)) != 2L)
    x[[j]] <- xj[i]
  
  ## Otherwise, call the same function, but with `drop`
  ## explicitly as FALSE (ignoring if it was set TRUE
  ## earlier). This way, we can stuff matrices (or other
  ## data.frames!) in without dropping attributes.
  else
    x[[j]] <- xj[i, , drop = FALSE]
}
{% endhighlight %}

Phew! I feel dizzy. Do you? We're actually not quite done --
there are two more branches of code dealing with more messy
`row.names` stuff, which isn't worth going into.
Overall, the code itself is
pretty unreadable (one has to slow down and think to have
a hope of understanding of what's going on).

What about performance? Surprisingly, there is nothing really
egregiously bad -- the main culprit is the use of temporaries,
alongside many calls to `[`. However, given that this is
implemented as a primitive (and `R` has gotten better about
performing shallow copies when appropriate) there aren't
too many needless allocations.

That said, there's nothing stopping us from implementing
the same functionality in `Rcpp`. Of course, having the same
amount of flexibility will be tough, but let's see what
we get specifically for an integer-integer subsetting case.
One could imagine implementing similar functionality for
different pairs of indexing, or forcing a final dispatch to
the integer-integer case.

This will be a slightly over simplified implementation that:

1. Neglects most error checking,
2. Only allows for integer vector subsetting,
3. Only allows subsetting for four of the atomic types
   (numeric, integer, logical, string),
4. Ignores `row.names`, and
5. Never drops.


{% highlight cpp %}
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
SEXP subset_df(SEXP x,
               IntegerVector row_indices,
               IntegerVector column_indices) {
                 
  // Get some useful variables (lengths of index vectors)
  int column_indices_n = column_indices.size();
  int row_indices_n = row_indices.size();
  
  // Translate from R to C indices.
  // This could be optimized...
  row_indices = row_indices - 1;
  column_indices = column_indices - 1;

  // Allocate the output 'data.frame'.
  List output = no_init(column_indices_n);

  // Set the names, based on the names of 'x'.
  // We'll assume it has names.
  CharacterVector x_names =
    as<CharacterVector>(Rf_getAttrib(x, R_NamesSymbol));

  // Use Rcpp's sugar subsetting to subset names.
  output.attr("names") = x_names[column_indices];

  // Loop and fill!
  for (int j = 0; j < column_indices_n; ++j)
  {
    // Get the j'th element of 'x'. We don't need to
    // PROTECT it since it's implicitly protected as a
    // child of 'x'.
    SEXP element = VECTOR_ELT(x, column_indices[j]);

    // Get the 'rows' for that vector, and fill.
    SEXP vec = PROTECT(
      Rf_allocVector(TYPEOF(element), row_indices_n)
    );
    
    for (int i = 0; i < row_indices_n; ++i)
    {
      // Copying vectors is a pain in the butt, because we
      // need to know the actual type underneath the SEXP.
      // I'll just handle a couple of the main types.
      switch (TYPEOF(vec))
      {
      case REALSXP:
        REAL(vec)[i] =
          REAL(element)[row_indices[i]];
        break;
      case INTSXP:
      case LGLSXP:
        INTEGER(vec)[i] =
          INTEGER(element)[row_indices[i]];
        break;
      case STRSXP:
        SET_STRING_ELT(vec, i,
          STRING_ELT(element, row_indices[i]));
        break;
      }
    }

    // And make sure the output list now
    // refers to that vector!
    SET_VECTOR_ELT(output, j, vec);

    // Don't need to protect 'vec' anymore
    UNPROTECT(1);
  }

  // Finally, copy the attributes of `x` to `output`...
  Rf_copyMostAttrib(x, output);

  // ... but set the row names manually.
  Rf_setAttrib(output, R_RowNamesSymbol,
    IntegerVector::create(NA_INTEGER, -row_indices_n));

  return output;

}
{% endhighlight %}

Let's see if it works. It should behave identically to
`df[i, j, drop = FALSE]`, for some subset of arguments.


{% highlight r %}
df <- data.frame(
  x = 1:5,
  y = letters[1:5],
  z = c(TRUE, FALSE, FALSE, TRUE, FALSE),
  stringsAsFactors = FALSE
)
subset_df(df, 1:3, 1:2)
{% endhighlight %}



{% highlight text %}
  x y
1 1 a
2 2 b
3 3 c
{% endhighlight %}



{% highlight r %}
subset_df(df, c(1, 2, 5), c(1, 3))
{% endhighlight %}



{% highlight text %}
  x     z
1 1  TRUE
2 2 FALSE
3 5 FALSE
{% endhighlight %}



{% highlight r %}
all.equal(
  subset_df(df, c(1, 2, 5), c(1, 3)),
  df[c(1, 2, 5), c(1, 3), drop = FALSE]
)
{% endhighlight %}



{% highlight text %}
[1] "Attributes: < Component \"row.names\": Mean relative difference: 0.6666667 >"
{% endhighlight %}

What about performance? Note that I am somewhat intentionally
cheating because I don't have any performance hit in
generating and populating the `row.names` attribute -- but
how much does it really matter?


{% highlight r %}
library("microbenchmark")

df <- data.frame(
  x = 1:1E2,
  y = sample(letters, 1E2, TRUE)
)

microbenchmark(
  R = df[5:10, 2, drop = FALSE],
  Cpp = subset_df(df, 5:10, 2)
)
{% endhighlight %}



{% highlight text %}
Unit: microseconds
 expr    min     lq     mean  median      uq     max neval cld
    R 80.340 82.495 87.78901 83.8175 90.4315 227.307   100   b
  Cpp  3.099  3.642  4.82325  4.0325  5.5970  29.331   100  a 
{% endhighlight %}

Yuck! `R` is really, really slow when it comes to taking
small subsets of a large vector, or at least much slower
than it should be. (For some more musing on this topic,
see [Extracting a single value from a data frame](http://adv-r.had.co.nz/Performance.html)
in Hadley's [`Advanced R`](http://adv-r.had.co.nz/) book.)
This is almost certainly due to the messy handling required
in generating and validating the `row.names` attribute,
as well as checking and handling of duplicate names.

However, we get these huge gains because:

1. We avoid allocating a bunch of temporary, unneeded
   objects at the `R` level,

2. We avoid the excessive branching associated with the
   `drop` argument,
   
3. We avoid unnecessary, repeated dispatches through `[`
   and directly access the memory we want to use --
   also permitting the compiler to make some optimizations
   as necessary,
   
More than performance, though, what really counts is that,
when uncommented, `R`'s implementation of `[.data.frame`
is pretty unreadable. You can [read the code online](https://github.com/wch/r-source/blob/c89a5896ebd1d16f7fea88f1a7f3238b774e27ba/src/library/base/R/dataframe.R#L536-L685),
which even comes with some (albeit bare) comments. It seems
unfortunate that `R` strips comments out of code included in
`base` (and other packages), since they would be enormously
useful for understanding what's going on.

In the end, what we see is that `[.data.frame` is really just
some calls to `[` (as a primitive dispatching to the internal,
non-data.frame implementation), `.subset()`, and `.subset2()`.
You can see such a simplified implementation in
[`dplyr`](https://github.com/hadley/dplyr/blob/366fa198c46084957f8a756c70263e23ea2a3118/R/tbl-df.r#L114-L146)
-- note the much more relatively clean
implementation that arises when the messiness of `drop` and
`row.names` is avoided!

One of the guiding tenants of `C++` is:

> you don't pay for what you don't use

and this is a very nice thing to keep in mind when implementing
functions and defining interfaces.
Unfortunately, this is very often not true in `R`, and
especially `[.data.frame`, where every call forces you to
check the hoops of `row.names`, `drop`, and uniqueness of
`names`, whether you care or not. Of course, the 
priorities of `R` and `C++` differ greatly, but it is an
important thing to keep in mind when attempting to write
performant `R` code.
