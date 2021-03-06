---
layout   : post
title    : C++ Unit Tests for R Packages
tags     : r, cpp
comments : true
---

Are you familiar with [testthat](http://r-pkgs.had.co.nz/tests.html)?
It's another package from the Hadleyverse that
makes it easy (and fun!) to write unit tests
for your R code. The tests you write look
something like this:


{% highlight r %}
context("Package Feature")

test_that("Feature works as expected", {
  number <- package::two_plus_two()
  expect_true(number == 4)
})
{% endhighlight %}

This is a great interface for testing R 
code... but code in a package isn't always 
R code. Wouldn't it be nice if we could do
something like this with our C / C++ code,
as well?

There are in fact a number of libraries for
unit testing of C / C++ code, but there
exists one that has a surprisingly
similar interface to `testthat` --
[Catch](https://github.com/philsquared/Catch).
Catch lets you write unit tests of the form:


{% highlight cpp %}
#include "catch.hpp"

int twoPlusTwo() {
  return 2 + 2;
}

TEST_CASE("Two plus two is four", "[arith]") {
  REQUIRE(twoPlusTwo() == 4);
}
{% endhighlight %}

This looks surprisingly `testthat`-like, but it's
not quite there. There's also the baggage of
figuring out how to compile and run the test
executable, which is just not fun.

Fortunately, the development version of 
`testthat` now bundles `Catch` and makes it
super easy to create and run Catch unit 
tests as a part of your regular R package
development workflow. Give it a shot in
your own package:


{% highlight r %}
devtools::install_github("hadley/testthat")
testthat::use_catch()
{% endhighlight %}

This will add the necessary test
infrastructure to your package. And now,
voila, when you test your package (say, by
pressing `Ctrl + Shift + T` in RStudio),
any Catch unit tests found in the the C++
files contained in your `src/` folder will
automatically be run. How slick is that?

The format of your C++ unit tests is (using
some handy `#define`s) is of the form:


{% highlight cpp %}
#include <testthat.h>

int twoPlusTwo() {
  return 2 + 2;
}

context("Arithmetic") {
  test_that("Two plus two is four") {
    expect_true(twoPlusTwo() == 4);
  }
}
{% endhighlight %}

That's virtually identical to the R code
formulation, barring some changes in where
the braces show up.  You can see how `testthat`
itself tests some example code
[here](https://github.com/hadley/testthat/blob/master/src/test-catch.cpp).

With this, I hope that unit testing of
compiled code in an R package will become
just as easy (and fun) as testing of the
R code itself. Test and be happy!
