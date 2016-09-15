---
layout   : post
title    : Pitfalls in Writing Portable C++98 Code
tags     : r
comments : true
---

I've now made enough submissions to [CRAN](https://cran.r-project.org/) that
have crashed and burned on Solaris, that I think it's now time to put some of
the pitfalls I've bumped into in writing. My goal is for this blog post to be
a mini-checklist you can run through before submitting your package to CRAN.

For the unaware -- the compilers used on the Solaris machines ([Oracle Solaris 
Studio](https://www.oracle.com/tools/developerstudio/index.html), or more 
recently, Oracle Developer Studio) are __very__ picky when it comes to C++ code 
that should respect the C++98 standard. This implies none of the goodies that 
are available with the C99 standard, nor some of the more 'minor' features of the
C++11 standard. Notably, `gcc` and `clang` often make these features available 
when compiling with `-std=c++98`, or otherwise make them available if the `-std`
flag is not explicitly specified, so it's very easily to accidentally fail to 
adhere to the C++98 standard, without really knowing it.

The CRAN Solaris build machines use the Oracle Studio compilers, alongside
their `stlport4` C++ standard library. Together, these adopt a very strict
interpretation of the C++98 standard. While `gcc` and `clang` often take a
"I know what you mean" approach to compiling your code, the Solaris compilers
take a more "this is what the standard says" approach.

With that said, let's get started.

### C++11

If you can use C++11 (or greater) when compiling your package's C++ code, _just
do it_. All of the platforms used on CRAN support C++11 now -- most recently, 
Windows joined the club with the toolchain update spearheaded by [Jeroen Ooms 
et. al](https://github.com/rwinlib/r-base#readme), and with much help from Duncan 
Murdoch + others.

The only reason _not_ to use C++11 nowadays is if your package needs to build on
older machines (Red Hat Enterprise Linux 5 + `gcc-4.4`, I'm looking at you), but
even then one can compile with `-std=c++0x` to get a subset of C++11 features.

For R packages, using C++11 is as simple as placing the following line in your
`src/Makevars` and `src/Makevars.win` files:

    CXX_STD = CXX11

The development versions of R even come with support for the C++14 standard. So,
if you can, please use modern C++ -- for your own sanity, and also as an extra 
layer of protection versus the common portability pitfalls.

> Rule: If you can, use the most recent version of the C++ standard available.

### Standard Library Headers

The following code may fail to compile on Solaris:

```cpp
#include <cstdio>
size_t string_length(const char* string) {
  return ::strlen(string);
}
```

```
kevin@soularis:~/scratch
$ CC -library=stlport4 string_length.cpp 
"string_length.cpp", line 3: Error: size_t is not defined.
"string_length.cpp", line 4: Error: strlen is not defined.
2 Error(s) detected.
```

The C++ standard library headers that 'wrap' their C counterparts are typically 
prefixed with a `c` and contain no extension, e.g. `<cstring>`; while the C 
headers themselves are typically given a `.h` extension, e.g. `<string.h>`. When
the `<cstring>` header is included in a translation unit, the C++98 standard
dictates that the compiler:

- *Must* define its members (e.g. `strlen`) in the `std::` namespace, and
- *May* define its members (e.g. `strlen`) in the _global_ namespace.

In fact, `gcc` and `clang` both accept the above code, but the Solaris compilers
do not. (The Solaris compilers do not populate the global namespace
when including these headers.)

> Rule: If you include a C++-style standard library header, reference symbols 
  from the `std` namespace. Prefer using C++-style standard library headers over 
  the original C counterpart.

### C99

The C++98 standard was ratified at an unfortunate time -- it came just one year
before the C99 standard, and the C99 standard introduced a number of tools that
make it easier to write safe + correct C code. Some of the newer pieces that
became part of the C99 standard made it into C++98, but some didn't.
Examples that I've bumped into thus far are:

- `long long`
- `snprintf` / `vsnprintf`
- `isblank`
- Fixed-width integer types (`uint8_t` etc., from [`<cstdint>`](http://en.cppreference.com/w/cpp/types/integer))
- Variadic macros

Since most compiler suites that compile C++ also compile C, such compilers 
typically make those symbols available to C++ code. However, strictly speaking, 
these are _not_ available in the C++98 standard, and so expect compiler errors 
on Solaris if you use these features.

> Rule: Avoid using symbols defined newly in the C99 standard, as the Solaris
  compilers may not make them available when compiling in C++98 mode.

### Exceptions

The following code may fail to compile on Solaris:

```cpp
#include <stdexcept>
void ouch() {
  throw std::logic_error("ouch!");
}
```

Can you guess why? In fact, the `logic_error` class has
[two constructors](http://en.cppreference.com/w/cpp/error/logic_error):

1. `explicit logic_error(const std::string& what_arg);`
2. `explicit logic_error(const char* what_arg);`

The second constructor was added only in C++11, so a strictly conforming C++98
compiler may not provide it. And, because the constructor is marked `explicit`, 
the compiler will not attempt to convert the user-provided `const char*` to 
`std::string`, to invoke the first constructor. As you can imagine, most 
friendly compilers will accept your code either way as the intention is obvious,
but don't expect Solaris to be friendly.

This omission is not unique to `logic_error`; it seems to be common to all
of the exception classes defined in [`<stdexcept>`](http://en.cppreference.com/w/cpp/header/stdexcept).

> Rule: Avoid constructing exception objects with C strings.

### Be Careful with `<cctype>`

Have you ever wanted to know whether a particular `char` is a letter, a number,
a whitespace character, or something else? The `<cctype>` header provides utilities
for assessing this, with e.g. [`std::isspace`](http://en.cppreference.com/w/cpp/string/byte/isspace).
Unfortunately, these functions are _dangerous_ for one main reason:

- The behavior is __undefined__ if the value of ch is not representable as
  `unsigned char` and is not equal to EOF.

Together, this implies a very counter-intuitive result for the following program
on Solaris:

```cpp
#include <stdio.h>
#include <cctype>

int main() {
    char ch = '\xa1'; // '¡' in latin-1 locales + UTF-8
    printf("is whitespace: %i\n", std::isspace(ch));
    return 0;
}
```

Compiled and run on Solaris, I see:

```sh
kevin@soularis:~/scratch
$ CC -library=stlport4 whitespace.cpp && ./a.out 
is whitespace: 8
```

What happened here? Well:

1. `'\xa1'` (normally, the '¡' character in latin-1 or UTF-8 locales) is assigned to a `char`,
2. Because the integer value of `'\xa1'` (`161`) lies outside the range of a `char`, it's
   converted to `-95` (`161 - 256`, wrapping around),
3. Because `-95` is not representable as an `unsigned char`, the program is undefined,
4. Solaris takes the 'undefined' interpretation literally, and gives you an
   unexpected result over an expected result.

Now, you might argue that the behavior is clearly documented and it's the
authors fault for writing a program that exhibits this behavior, but it's
unfortunately easy to do. For example:

```cpp
#include <cctype>

int countWhitespace(const char* bytes) {
  int count = 0;
  while (std::isspace(*bytes++))
    ++count;
  return count;
}
```

This is the kind of program that only looks obviously wrong if you're an expert,
and I think even experts could miss this. The solution is to explicitly cast
any `char`s to `unsigned char` before passing them to `<cctype>` functions.

Or, just write your own wrapper functions that accept `const char*` and do the
right thing. For example, it might suffice to just use:

```cpp
boolean isWhitespace(char ch) {
  return
    ch == ' ' ||
    ch == '\f' ||
    ch == '\r' ||
    ch == '\n' ||
    ch == '\t' ||
    ch == '\v';
}
```

This of course does not capture all kinds of whitespace characters. For example,
the Unicode standard defines a whole slew of [multibyte white space characters](https://en.wikipedia.org/wiki/Whitespace_character);
figuring out how to handle all of that is beyond the scope of this
post.

Interestingly, the wide character analogues defined in
[`<cwctype>`](http://en.cppreference.com/w/cpp/string/wide/iswspace) don't
appear to come with the same caveat, and hence should be safer to use.

> Rule: Be careful when using `<cctype>` -- either write your own wrappers, or ensure
  you cast to unsigned char first.

### The R Manuals

If you're not already aware, the [R Manuals](https://cran.r-project.org/manuals.html), and 
[Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html) in
particular, are excellent references for common issues encountered when using R.
They're not perfect -- I often find it difficult to remember which manual
contains which bit of relevant information I'm looking for -- but they are
incredibly comprehensive and actively updated by the R Core team.

The section in _Writing R Extensions_ on [Portable C and C++ 
code](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Portable-C-and-C_002b_002b-code)
is a very nice reference for common portability pitfalls in the C++ code 
used by R packages that the CRAN maintainers have seen throughout the years. 
Treat this section as another mini-checklist before submitting an R package 
containing C++ code to CRAN.

> Rule: Review the 'Portable C and C++ Code' section before submitting your package to CRAN.

### Leaky Compilers

Unfortunately, some compilers will leak macro definitions that can conflict with
your code unexpectedly. Some such symbols, as discussed in [Portable C and C++ 
code](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Portable-C-and-C_002b_002b-code),
are:

- `ERR`
- `zero`
- `I`
- `CS`, `DS`, `ES`, `FS`, `GS` and `SS`

Solaris isn't the only leaky compiler -- `gcc` also 'leaks' `major` and `minor` macro definitions
when including `<sys/sysmacros.h>`, and this header might find its way into your program when
including, for example, `<iterator>`. (See [here](http://stackoverflow.com/questions/22240973/major-and-minor-macros-defined-in-sys-sysmacros-h-pulled-in-by-iterator) for one such example.)

> Rule: Be aware of macro pollution.

### Don't Panic

Let's be honest. It's _really_ easy to make mistakes when attempting to write 
C++ code that strictly adheres to the C++98 standard, and portability issues 
create frustration for everyone (you and the CRAN maintainers included). The net
result is still a better package that is more likely to be portable outside of 
the `gcc` / `clang` ecosystem.

Do your best, be friendly and up-front with the CRAN maintainers when you're
submitting (or re-submitting) a package containing C++ code that produces
compiler errors, and try to learn a little bit more each time.

> Rule: Remember to take a deep breath, and be patient.

## Wrapping Up

Hopefully, this post will help you (or possibly just future me) to avoid
headaches with your next CRAN package submission containing C++ code.

And, to re-iterate once more, if you can use C++11 (or greater), _do it_!
