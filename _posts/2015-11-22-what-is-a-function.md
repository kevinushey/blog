---
layout   : post
title    : What is a Function?
tags     : r
comments : true
---

Let's investigate what, underneath the 
covers, an `R` function really is, and how 
the components are used when `R` evaluates 
a function. In doing so, we'll take a 
number of detours, as understanding how `R`
function calls really work requires an
understanding of some subtle details. By 
the end of this, we'll be able to simulate 
what `R` does internally when it evaluates 
a function.

## The Three Musketeers

As you might already know from
[adv-r](http://adv-r.had.co.nz/Functions.html),
(or, if you're brave, the
**Technical Details** section of `?"function"`),
functions are `R` objects made up of three
components:

1. A function body,
   
2. An environment, and
   
3. A set of formals.

Let's look at these components individually,
then see how they're used together when
evaluating a function.

### The Function Body

The body of a function can be accessed
with the `body()` function. Let's take
a peek at the body of a simple function:


{% highlight r %}
fn <- function(x) { print(x) }
body(fn)
{% endhighlight %}



{% highlight text %}
{
    print(x)
}

{% endhighlight %}

This is just the unevaluated call verbatim
as we wrote above. It's made up `R`
language objects, called `symbol`s and 
`call`s. It produces a result when 
evaluated within an environment.


{% highlight r %}
# use 'pryr::ast' to print the abstract
# syntax tree; ie, the whole structure
# of the call object as R sees it.
do.call(pryr::ast, list(body(fn)))
{% endhighlight %}



{% highlight text %}
\- ()
  \- `{
  \- ()
    \- `print
    \- `x 

{% endhighlight %}

In other words, pedantically, it's a call
to the `{` primitive function, which
internally is calling the `print` function
with the `x` symbol as an argument.

Note that these symbols do not have any
meaning until they are evaluated, and their
meanings depend on which environment they
are evaluated in.

Pedantically, the above function involves a
call to the `{` symbol, which will
eventually be resolved as `base::"{"` on
evaluation, although one could potentially
override this with their own definition of
`{`. Of course, overriding this function is
definitely not recommended!


{% highlight r %}
"{" <- function(...) print("Hello!")
{1 + 2}
{% endhighlight %}



{% highlight text %}
[1] "Hello!"

{% endhighlight %}



{% highlight r %}
rm("{")
{% endhighlight %}

You might be surprised to see that almost all
of the syntactic elements in `R` actually
become function calls after parsing!

But I digress. We understand now that the
function body is just an unevaluated call.
Let's move on to the function environment.

### The Function Environment

The environment associated with a function 
is typically the environment where the 
function was created. This is where symbols
within the `body()` of a function that
aren't in the function formals will be 
resolved.


{% highlight r %}
# create a function -- its associated env
# is the global environment.
# it references a (global) symbol 'a'.
foo <- function() a
environment(foo)
{% endhighlight %}



{% highlight text %}
<environment: R_GlobalEnv>

{% endhighlight %}



{% highlight r %}
# calling foo() right now fails, as there's
# no 'a' in the global environment.
foo()
{% endhighlight %}



{% highlight text %}
Error in foo(): object 'a' not found

{% endhighlight %}



{% highlight r %}
# assign 'a' in the global env, then
# evaluate the function. all is well!
a <- 1
foo()
{% endhighlight %}



{% highlight text %}
[1] 1

{% endhighlight %}



{% highlight r %}
# set the function environment to an empty
# env -- 'a' will no longer be resolved as
# it does not exist in that environment.
env <- new.env(parent = emptyenv())
environment(foo) <- env
foo() 
{% endhighlight %}



{% highlight text %}
Error in foo(): object 'a' not found

{% endhighlight %}



{% highlight r %}
# put 'a' in that environment, and now
# evaluation will succeed again.
env$a <- 1
foo()
{% endhighlight %}



{% highlight text %}
[1] 1

{% endhighlight %}

Typically, this environment is called the 
_enclosing_ environment -- this is where 
'global', or 'non-local', symbols will be 
resolved. What does it enclose? And how
exactly do function formals get resolved?

Every time a function is evaluated, a _new_
environment is generated, and any passed
formal arguments are bound within that
environment. We'll call this the local
evaluation environment, and its parent
environment is the aforementioned enclosing
environment. The evaluation environment can
be accessed by calling `environment()`
within the function body. Let's demonstrate
this:


{% highlight r %}
fn <- function(a, b, c) {
  # the formals are made available as part
  # of the evaluation env. we'll look at
  # this more deeply later.
  formals <- ls(environment())
  
  # the parent env -- typically
  # where the function was generated.
  parent_env <- parent.env(environment())
  
  # return all the bits for inspection.
  list(eval = environment(),
       parent = parent_env,
       formals = formals)
}

# invoke the function twice, just to
# demonstrate that each invocation gets
# its own local eval env.
c(first = fn(), second = fn())
{% endhighlight %}



{% highlight text %}
$first.eval
<environment: 0x7fcfc5e0f188>

$first.parent
<environment: R_GlobalEnv>

$first.formals
[1] "a" "b" "c"

$second.eval
<environment: 0x7fcfc5e0cd78>

$second.parent
<environment: R_GlobalEnv>

$second.formals
[1] "a" "b" "c"

{% endhighlight %}

Although it is typically bad form to have 
functions depend on global variables, it 
can be useful when functions are defined or
returned within functions. Let's illustrate
with an example.

The following function `make_fn()` returns 
a function, whose enclosing environment is
the local environment created when invoking
`make_fn()` itself. Note that this means 
that each function returned by `make_fn()` 
gets its own copy of symbols generated when
evaluating the function body:


{% highlight r %}
make_fn <- function() {
  # assign 'x' within the local, newly
  # generated <make_fn> environment.
  x <- 1
  
  # create and return a function, whose parent
  # env is the <make_fn> environment. that means
  # it has a reference to the 'x' symbol defined
  # before.
  return(function() {
    # use 'parent assign' to update 'x'.
    x <<- x + 1
    x
  })
}

# create a couple functions using 'make_fn()'.
# what do you expect the output of each call to be?
fn1 <- make_fn()
fn2 <- make_fn()
c(fn1(), fn1(), fn1())
{% endhighlight %}



{% highlight text %}
[1] 2 3 4

{% endhighlight %}



{% highlight r %}
fn2()
{% endhighlight %}



{% highlight text %}
[1] 2

{% endhighlight %}

We now have a few key pieces of 
understanding in how `R` function 
evaluation works. When evaluating a 
function,

1. A new, local, environment is generated,
   with its parent environment being the
   enclosing environment of the called
   function,
   
2. The formals are bound within that local
   environment,

3. The function body is evaluated in that
   local environment.

We have the main pieces, but 2. is a bit
fuzzy. How exactly are the formals bound
within that environment? How do default
arguments work?

### The Function Formals

The formals of a function can be accessed with
`formals()`. It is an `R` object that maps
argument names to default values (if they exist).


{% highlight r %}
# print the function to get a synopsis of its
# formals + body + enclosure.
stats::rnorm
{% endhighlight %}



{% highlight text %}
function (n, mean = 0, sd = 1) 
.Call(C_rnorm, n, mean, sd)
<bytecode: 0x7fcfc5d21070>
<environment: namespace:stats>

{% endhighlight %}



{% highlight r %}
# get the formals explicitly.
str(formals(stats::rnorm))
{% endhighlight %}



{% highlight text %}
Dotted pair list of 3
 $ n   : symbol 
 $ mean: num 0
 $ sd  : num 1

{% endhighlight %}

We can see that `stats::rnorm()` takes three
arguments: `n`, `mean` and `sd`; and the
argument `mean` gets a default of `0`, while
`sd` gets a default of `1`.

Note that, since `n` does not receive a
default argument, it is assigned the so-called
'missing' symbol. Attempting to evaluate this
symbol directly throws an error:


{% highlight r %}
fm <- formals(stats::rnorm)

# accessing a missing symbol within
# a pairlist is, strangely, okay.
fm$n
{% endhighlight %}




{% highlight r %}
# internally, it's a symbol with no name
# (the so called 'R_MissingArg' symbol).
.Internal(inspect(fm$n))
{% endhighlight %}



{% highlight text %}
@7fcfc5002108 01 SYMSXP g1c0 [MARK,NAM(2)] "" (has value)

{% endhighlight %}



{% highlight r %}
# attempting to evaluate it directly
# will return an error.
n <- fm$n
n
{% endhighlight %}



{% highlight text %}
Error in eval(expr, envir, enclos): argument "n" is missing, with no default

{% endhighlight %}

In case you're curious, you can create the
so-called missing symbol with the call
`quote(expr = )`. (Looks, weird, I know.)
Just to confirm:


{% highlight r %}
x <- quote(expr = )
x
{% endhighlight %}



{% highlight text %}
Error in eval(expr, envir, enclos): argument "x" is missing, with no default

{% endhighlight %}

Knowing what we already do about how
function evaluation works, we just need
to figure out how the formals are 'inserted'
into the local function environment.


{% highlight r %}
foo <- function(a = 1, b) {
  # demonstrate that 'a' and 'b' exist
  # in the function's local environment
  print(ls(environment()))
  
  # access and return those symbols
  e <- environment()
  c(e$a, e$b)
}

# set 'b': works as expected
foo(1, 2)
{% endhighlight %}



{% highlight text %}
[1] "a" "b"

{% endhighlight %}



{% highlight text %}
[1] 1 2

{% endhighlight %}



{% highlight r %}
# leave 'b' unset
# quiz: why does this succeed?
foo(1)
{% endhighlight %}



{% highlight text %}
[1] "a" "b"

{% endhighlight %}



{% highlight text %}
[[1]]
[1] 1

[[2]]

{% endhighlight %}

So, when `foo()` above is evaluated, the
formals `a` and `b` have already been bound
within the generated local environment. But
there's still the over-arching question:
when, and how, are they bound exactly? If
we assign an argument name the result of an
expression, e.g. `foo(x = 1 + 2)`, when will
`1 + 2` be evaluated?

Let's illustrate with an example. Try to guess what
the output of the following function call will be.


{% highlight r %}
fn <- function(x) {
  cat("+ fn\n")
  x # (1)
  x # (2)
  cat("- fn\n")
}

fn(x = cat("> x\n"))
{% endhighlight %}



{% highlight text %}
+ fn
> x
- fn

{% endhighlight %}

You might be surprised that `> x` is not
printed until `x` is actually evaluated in
the function body, and that it is only
printed once. Why is that?

This demonstrates `R`s lazy evaluation of
function arguments. When `R` binds
formals to the local generated function
environments, it does so with a _promise_.
Roughly speaking, a _promise_ is a
transient object that does not produce the
result of its evaluation until explicitly
requested. It is only evaluated once; after
it has been evaluated, the returned value
is stored and returned on any later 
subsequent evaluations of that object.

This means that, in the first call to `x`
above, the expression `cat("> x\n")` is
evaluated, and its result is returned and
assigned to `x` (in this case, calling the
`cat()` function just returns `NULL`). The
second time, we've already 'forced' the
promise, and so we don't evaluate `x`
again.

We now understand all the main pieces in 
how `R` evaluates a function! I am glossing
over the details related to argument
matching. Given what you know now, try to
convince yourself that this stage simply
maps function argument names to promises to
be executed later -- either with the 
default argument, or an argument provided
by you, the user.

Pop quiz: can you predict the result of
this function call?


{% highlight r %}
tricky <- function(x = y <- TRUE) {
  x
  y
}
tricky()
{% endhighlight %}



{% highlight text %}
[1] TRUE

{% endhighlight %}

Because `x` is a promise, with expression
`y <- TRUE`, when that promise is evaluated
we bind the symbol `y` with value `TRUE` in
the executing environment. Therefore,
attempting to access `y` after forcing the
promise bound to `x` will succeed.

That said, please don't actually write code
like this.

### Putting it Together

Given the above, let's try simulating
what happens during function evaluation
ourselves. We'll make use of one tool,
`delayedAssign()`, which will allow us
to generate a promise.


{% highlight r %}
## attempt to evaluate the aformentioned
## 'fn', with 'x = cat("> x\n")'.

# collect our three musketeers from the
# aforementioned 'fn' function.
formals <- formals(fn)
body <- body(fn)
fn_env <- environment(fn)

# generate an env to host evaluation.
eval_env <- new.env(parent = fn_env)

# bind 'x = cat("> x\n")' in that env,
# as a promise.
delayedAssign("x", cat("> x\n"),
              eval_env, eval_env)

# evaluate the fn body in that env.
eval(body, envir = eval_env)
{% endhighlight %}



{% highlight text %}
+ fn
> x
- fn

{% endhighlight %}

And voila -- we've successfully simulated
function evaluation in `R`. Now let's put
this all together in a function. We'll
call it `evalf()`, for 'evaluate function'.


{% highlight r %}
# evaluate a function, binding named arguments
# in '...' to the local evaluation env
evalf <- function(fn, ...) {
  
  # collect the main pieces we need for eval
  body <- body(fn)
  fn_env <- environment(fn)
  formals <- formals(fn)
  eval_env <- new.env(parent = fn_env)
  
  # capture unevaluated expressions passed
  # within the dots
  dots <- eval(substitute(alist(...)))
  
  # assign default arguments
  # note that, because 'delayedAssign' tries
  # to capture the passed expression as-is,
  # we use 'do.call' for force e.g. 'formals[[i]]'
  # to evaluate to the actual expression within
  for (i in seq_along(formals)) {
    do.call(base::delayedAssign, list(
      names(formals)[[i]], formals[[i]],
      eval_env, eval_env
    ))
  }
  
  # override with user-supplied args
  for (i in seq_along(args)) {
    do.call(base::delayedAssign, list(
      names(dots)[[i]], dots[[i]],
      eval_env, eval_env
    ))
  }
  
  # evaluate it!
  eval(body, envir = eval_env)
}

# run our original example function
evalf(fn, x = cat("> x\n"))
{% endhighlight %}



{% highlight text %}
+ fn
> x
- fn

{% endhighlight %}



{% highlight r %}
# try calling 'rnorm' with 'n = 2'
evalf(rnorm, n = 2)
{% endhighlight %}



{% highlight text %}
[1] -0.09113057 -0.34948505

{% endhighlight %}

_Voila!_

Note that this scheme really is quite
simplified -- it does not capture what
happens with S3 or S4 dispatch, and it
also does not reflect what happens when
so-called `primitive` functions are
called:


{% highlight r %}
evalf(c, 1, 2, 3)           # nope!
{% endhighlight %}



{% highlight text %}
Error in new.env(parent = fn_env): use of NULL environment is defunct

{% endhighlight %}



{% highlight r %}
evalf(head, x = 1:10)       # sorry!
{% endhighlight %}



{% highlight text %}
Error in eval(expr, envir, enclos): generic 'function' is not a function

{% endhighlight %}

It does otherwise accurately portray
how evaluation of 'vanilla' `R` functions
works. Behind the scenes, `R`
will handle dispatch and such using C code,
and perform non-standard evaluation to
handle things like the use of `UseMethod()`
within a function body.

Hopefully this exercise has helped you
piece together what happens behind the
scenes in `R` function evaluation, and
given you some understanding of how
`R`'s lazy evaluation of function
arguments works.

______

EDIT 1: Improved implementation of `evalf()`;
the original version did not capture promises
appropriately.
