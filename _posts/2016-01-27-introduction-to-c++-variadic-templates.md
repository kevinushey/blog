---
layout   : post
title    : Introduction to C++ Variadic Templates
tags     : cpp
comments : true
---

This is a friendly introduction to variadic templates
(and thereby, variadic functions) in C++. We can use
variadic functions to write functions that accept an
arbitrary number of arguments.

First, let's focus on the syntax: how do we _read_
a variadic template? What are the different syntactic
elements, and what are they called? Let's look at a
simple example. We'll create a variadic function `ignore`
that does nothing (it ignores its arguments).


{% highlight cpp %}
template <typename... Ts>  // (1)
void ignore(Ts... ts) {}   // (2)
{% endhighlight %}

1. We use `typename... Ts` to declare `Ts` as a
   so-called **template parameter pack**. You'll often see
   these called as e.g. `Ts`, as in, multiple `T`s. Other
   common names are `Args`, or `Rest`. The ellipsis (`...`)
   operator is used here to declare that `Ts` truly is a
   template parameter pack.

2. Our function signature accepts a closely-related
   **function parameter pack** -- in other words, a bag of
   parameters, whose types are given by the aforementioned 
   **template parameter pack**. It is declared as
   `Ts... ts`, with the ellipsis operator used to indicate that
   `Ts` does refer to a template parameter pack.
   
You can mentally unwrap the above definition of `ignore` as:


{% highlight cpp %}
template <typename T1, typename T2, ..., typename Tn>
void ignore(T1 t1, T2 t2, ..., Tn tn) {}
{% endhighlight %}

This also makes it clear that each type in the template parameter
pack can be different -- just to be concrete, calling:


{% highlight cpp %}
ignore(1, 2.0, true);
{% endhighlight %}

has the effect of instantiating our templated function with
types `ignore<int, double, bool>(1, 2.0, true)`.

An important side note: it's possible for a template parameter
pack to contain 0 types. This might be somewhat obvious, but
it'll become more important later.

Okay, we know what they are -- but how do we use them? How do
we implement a variadic function that does some real work?

Let's start by implementing a variadic sum -- it'll take
a bunch of arguments, and just attempt to add them all up.
We'll assume that the function returns a `double` for now,
although in practice you'd probably like the result to
depend on the input types (e.g. adding two `int`s should
probably return an `int`).

If you're like me, the first thing you probably wished you
could write was something like:


{% highlight cpp %}
template <typename... Ts>
double sum(Ts... ts) {
  double result = 0.0;
  for (auto el : ts)
    result += el;
  return result;
}
{% endhighlight %}

Unfortunately, this won't do. Here's what I get from `clang`:

    error: expression contains unexpanded parameter pack 'ts'
      for (auto el : ts)
                     ^~

When it comes to handling variadic functions, you can't
think in the standard 'iterative' C++ style. You need to
write such functions recursively -- with a 'base' case, and
a 'recursive' case that reduces, eventually, into a 'base'
case. This implies a separate function for each case.

Unfortunately, none of this makes sense until you see
an example. So let's start with a working example, and then
break it down.


{% highlight cpp %}
// The base case: we just have a single number.
template <typename T>
double sum(T t) {
  return t;
}

// The recursive case: we take a number, alongside
// some other numbers, and produce their sum.
template <typename T, typename... Rest>
double sum(T t, Rest... rest) {
  return t + sum(rest...);
}
{% endhighlight %}

We have our 'base' case, accepting one argument `T`,
and our 'recursive' case, accepting one or more arguments
`T` and `Rest`. (Recall that a template parameter pack can be empty!)

How exactly does this work? Let's trace what happens when
we try to call, for example, `sum(1.0, 2.0, 3.0)`. This is going
to be a bit repetitive, but it's worth it to walk through
the process at least once.

1. The compiler generates code for `sum(1.0, 2.0, 3.0)`.
   There are two competing overloads for `sum` here: the
   base case, and the recursive case. Since we're passing in
   three arguments, the base case does not apply (it only
   accepts a single argument), so we select the recursive case.
  
2. Type deduction is performed -- the compiler deduces
   `T = double`, and puts the rest in our parameter pack,
   with `Rest = <double, double>`.

3. The compiler generates code for `t + sum(rest...)`. It
   sees the recursive call to `sum(rest...)`. Note the use of
   `...` to 'unpack' the template argument -- this has the 
   effect of transforming `sum(rest...)` to `sum(2.0, 3.0)`.

4. The compiler generates code for `sum(2.0, 3.0)`. As in the first case,
   there are two competing overloads: the base case, and the
   recursive case. The base case once again does not apply as
   we have more than one argument, so we select the recursive case.
   
5. Type deduction is performed -- the compiler deduces
   `T = double`, and `Rest = <double>`. It's subtle, but
   notice that we have now unpacked our original
   `<double, double>` pack to `T = double` and `Rest = <double>`.
   
6. The compiler generates code for `t + sum(rest...)`. It
   sees the recursive call to `sum(rest...)` -- this time,
   with `sum(rest...)` expanding to simply `sum(3.0)`.

7. The compiler generates code for `sum(3.0)`. We have now finally
   hit our base case: the overload taking only `T` is more specialized,
   relative to the overload taking both `T` and `Ts...`. The compiler
   generates code for the base case, and we're done with the recursion.

All in all, the expression expands in the following way (using indices
to distinguish the various `t`s produced on expansion):

    t0 + sum(rest...);         // initial state
    t0 + sum(t1, t2);          // unpack 'rest...' as 't1, t2'
    t0 + (t1 + sum(rest...));  // replace 'sum(t1, t2)' with code
    t0 + (t1 + sum(t2));       // unpack 'rest...' as 't2'
    t0 + (t1 + (t2));          // 'sum(t2)' --> base case!
    
Or, if you prefer seeing it with numbers,

    sum(1.0, 2.0, 3.0);
    1.0 + sum(2.0, 3.0);
    1.0 + (2.0 + sum(3.0));
    1.0 + (2.0 + (3.0));

And there we have it. Although our sum implementation makes use of
compile-time recursion, the end result is a linear addition of code.
Let's outline the main techniques we've learned here:

* To unpack a parameter pack, use a templated function taking
  one (or more) parameters explicitly, and the 'rest' of the
  parameters as a template parameter pack.
  
* Recurse towards a base case: call your recursive function with
  the 'rest...' arguments, and let the compiler unpack your parameters
  in subsequent calls to your recursive function.

* Allow your base case to overload your recursive case -- it will
  be selected in preference to the recursive case as soon as the
  parameter pack is empty.

Using variadic functions does indeed require a bit of a
change in mindset, and is somewhat more verbose (given the 
amount of code required to write the base and recursive
cases).  However, these are the main tools you need for
performing computation with variadics: unpack and reduce.

Let's make our function a little bit more clever: how about
instead of computing the sum, we compute something like:

$$ x_1^1 + x_2^2 + x_3^4 $$


{% highlight cpp %}
// A function that 'squares' a number; ie, multiples
// it by itself.
template <typename T>
T square(T t) { return t * t; }

// Our base case just returns the value.
template <typename T>
double power_sum(T t) { return t; }

// Our new recursive case.
template <typename T, typename... Rest>
double power_sum(T t, Rest... rest) {
  return t + power_sum(square(rest)...);
}
{% endhighlight %}

Notice the expression `square(rest)...`. Recall that the `...`
operator will expand an entire expression, so for example,
when it's called with `square(4.0, 6.0)...`, the compiler expands
this as `square(4.0), square(6.0)`. Let's trace the expansion of
the resulting code:

    power_sum(2.0, 4.0, 6.0);
    2.0 + power_sum(square(rest)...);
    2.0 + power_sum(square(4.0), square(6.0));
    2.0 + (square(4.0) + power_sum(square(rest)...))
    2.0 + (square(4.0) + power_sum(square(square(6.0)));
    2.0 + (square(4.0) + (square(square(6.0))))

It's important to note that `...` can be used to expand a 
_whole expression_ containing a parameter pack -- this is 
what makes it so powerful! On the downside, this expansion 
can only occur in certain contexts, e.g. within a function
call. Clever use of `...` expansion can allow you to avoid
recursion in some cases, although some extra tricks beyond
the scope of this article are required.

## Conclusion

We've outlined some of the basic tools and patterns for
implementing variadic functions:

- Use recursion to implement variadic functions -- implement
  a base case, and a recursive case, and have the recursive
  case reduce to a base case call;

- Use `...` to unpack parameter packs, or in more clever
  contexts, to unpack whole expressions containing a parameter
  pack.

As an aside, I tried to sidestep issues related to
pass-by-reference vs. pass-by-value vs. so-called 'perfect forwarding',
as they're somewhat orthoginal to understanding variadic
functions alone. However, if you want to learn more, you
should check out
[Perfect forwarding and universal references in C++](http://eli.thegreenplace.net/2014/perfect-forwarding-and-universal-references-in-c/).

## Further Reading

These are the resources I found most helpful when getting
familiar with variadic templates, and will also outline
some other techniques for effective use / implementations.

- [Using Variadic Templates Cleanly](http://florianjw.de/en/variadic_templates.html) --- focuses on using `...` to unpack expressions, helping to avoid recursion.
- [Variadic Templates in C++](http://eli.thegreenplace.net/2014/variadic-templates-in-c/) --- goes deeper, discussing variadic data structures and more.
- [CppReference](http://en.cppreference.com/w/cpp/language/parameter_pack) --- the 'standardese' description of parameter packs, with some helpful examples.

## Addendum

Please note that I'm not a C++ expert; there's likely a 
number of holes in my understanding, but what I divulge here
will still hopefully be useful to other beginners.
