---
layout   : post
title    : Debugging with Valgrind
tags     : r
comments : true
---

Those of you who have attempted to write packages using
C or C++ source code probably know this picture very 
well:

![rstudio-bomb]({{ site.baseurl }}/images/rstudio-bomb.png)

(Or, maybe you just enjoy running the development version
of [dplyr](https://github.com/hadley/dplyr).)

Alternatively, if you prefer using R from the console,
then you might have seen this, or some version of it:

    *** caught segfault ***
    address 0x18, cause 'memory not mapped'

These kinds of errors can be among the most difficult
to debug -- what's happening here is that the system
has detected that we've attempted to use memory in a
way we're not allowed to, but we've been given no
other information about who, what, when, where, why,
how...

This sort of error most commonly occurs when writing
C or C++ source code, and you attempt to access
memory out of bounds. Here's a simple example of an
Rcpp function that will cause a segfault:


{% highlight cpp %}
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector ouch() {
  NumericVector x(10);
  x[1000000] = 1;
  return x;
}
{% endhighlight %}

Hopefully, even if you're not well-versed in Rcpp,
the error is obvious: we're creating a vector of
length 10, and then attempting to write to that
same vector at index 1000000. Yikes! Of course, when
you do something like this in R you do not get such
disasterous consequences:


{% highlight r %}
x <- numeric(10)
x[1000000] <- 1
head(x, 20)
{% endhighlight %}



{% highlight text %}
​ [1]  0  0  0  0  0  0  0  0  0  0 NA NA NA NA NA NA NA NA NA NA

{% endhighlight %}

R just automatically extends the array for you
(actually, this is pretty darn surprising -- one would
expect R would instead give a warning, or error, or
something else -- extending and padding with `NA`s with
no prior warning seems scary)

Regardless, the point here is that R code verifies that
the underlying C machiney that executes whatever R code
you give it won't cause a segfault; once we drop down 
ourselves to the C / C++ level, we no longer have that 
luxury. The prize is incredibly fast, efficient code 
when we get it right; the cost is many hours lost 
debugging when we get it wrong.

What tools do we have for debugging problems like this?
There are actually a number of [very nifty static
analysis tools](http://clang-analyzer.llvm.org/) that
are emerging, but today we're going to look at the
tried and true [valgrind](http://valgrind.org/).

Valgrind, roughly speaking, is a program that runs 
other programs in a special monitoring environment, 
where it can extract information on what the program
did during execution. There are a variety of 
[tools](http://valgrind.org/info/tools.html) built into
valgrind -- really, you can basically think of them as 
separate programs -- which analyze different facets of 
how your program executes. The default tool, `memcheck`,
does what it says on the tin -- it checks how the
attached program is using memory, and lets us know if
when we fail to use it correctly. We're going to use it
to debug a segfault.

## Quickstart -- Installing Valgrind

These instructions will be super brief -- if you need
more information, you might need to consult your trusty
friend Google.

If you're on Windows, sorry -- I don't think `valgrind`
works in your town. I suggest moving.

If you're on a Unix-alike, you can probably just write 
`sudo apt-get install valgrind` or
`sudo yum install valgrind` or what have you.

On OS X, you need to install `valgrind` from source; I
suggest doing so with [homebrew](http://brew.sh/) --
use `brew install valgrind --HEAD`.

## Training Wheels

Before we start thinking about debugging our own code,
let's just figure out how to start R with `valgrind`.
Fortunately, it's easy. Try writing:

    R -d valgrind

in the console. The `-d` flag tells R to run itself
under a particular debugger; in this case, `valgrind`.
After doing this, you should see something like
(don't worry if your output is slightly different):

    ==92837== Memcheck, a memory error detector
    ==92837== Copyright (C) 2002-2013, and GNU GPL'd, by Julian Seward et al.
    ==92837== Using Valgrind-3.11.0.SVN and LibVEX; rerun with -h for copyright info
    ==92837== Command: /Library/Frameworks/R.framework/Resources/bin/exec/R --min-vsize=2048M --min-nsize=20M --no-restore
    ==92837== 
    --92837-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option
    --92837-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 2 times)
    --92837-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 4 times)
    --92837-- UNKNOWN host message [id 412, to mach_host_self(), reply 0x317]
    --92837-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 8 times)
    --92837-- UNKNOWN host message [id 222, to mach_host_self(), reply 0x317]
    --92837-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 16 times)
    ==92837== Warning: ignored attempt to set SIGUSR2 handler in sigaction();
    ==92837==          the SIGUSR2 signal is used internally by Valgrind
    
    R Under development (unstable) (2015-04-05 r68149) -- "Unsuffered Consequences"
    Copyright (C) 2015 The R Foundation for Statistical Computing
    Platform: x86_64-apple-darwin14.1.0 (64-bit)
    
    R is free software and comes with ABSOLUTELY NO WARRANTY.
    You are welcome to redistribute it under certain conditions.
    Type 'license()' or 'licence()' for distribution details.
    
      Natural language support but running in an English locale
    
    R is a collaborative project with many contributors.
    Type 'contributors()' for more information and
    'citation()' on how to cite R or R packages in publications.
    
    Type 'demo()' for some demos, 'help()' for on-line help, or
    'help.start()' for an HTML browser interface to help.
    Type 'q()' to quit R.
    
    Using libraries at paths:
    - /Users/kevinushey/Library/R/3.3/library
    - /Library/Frameworks/R.framework/Versions/3.3/Resources/library
    >

You can safely ignore the initial warning boilerplate.
What you have now is an R session running in the safe,
warm embrace of `valgrind`. Let's just `quit()` that R
session now and see what `valgrind` tells us:

    > quit()
    Save workspace image? [y/n/c]: n
    ==92837== 
    ==92837== HEAP SUMMARY:
    ==92837==     in use at exit: 80,588,360 bytes in 40,772 blocks
    ==92837==   total heap usage: 61,481 allocs, 20,709 frees, 103,195,896 bytes allocated
    ==92837== 
    ==92837== LEAK SUMMARY:
    ==92837==    definitely lost: 6,535,823 bytes in 88 blocks
    ==92837==    indirectly lost: 29,286 bytes in 120 blocks
    ==92837==      possibly lost: 57,158,070 bytes in 29,566 blocks
    ==92837==    still reachable: 16,865,181 bytes in 10,998 blocks
    ==92837==         suppressed: 0 bytes in 0 blocks
    ==92837== Rerun with --leak-check=full to see details of leaked memory
    ==92837== 
    ==92837== For counts of detected and suppressed errors, rerun with: -v
    ==92837== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 173 from 1)

This is the most basic report from a 'successful' run 
of `valgrind` -- it just reports to us details of 
leaked memory. If you don't know what that means, 
basically, at the C / C++ level, whenever you
explicitly request memory, you also have to explicitly
'give it back' when you're done using it -- when you
don't give it back, you have a memory leak. Continuous
memory leaks in programs lead to degraded performance
over time, and eventual crashes due to no more memory
being available. (Fortunately, if you're using Rcpp,
you almost never need to worry about that stuff as
R + Rcpp will manage it behind the scenes for you)

You may be surprised to see that `valgrind` believes 
that R has leaked memory -- unfortunately, it is not 
perfect, and in this particular case the memory is not 
so much 'leaked' as it is 'cached for the duration of 
that R session', and `valgrind` fails to detect that 
'ownership' of a particular block of memory is
transfered.

## Our First Segfault

Okay, now let's try making R segfault. Put this into a 
file, `segfault.cpp`, and make sure you have Rcpp
installed (`install.packages("Rcpp")`):

{% highlight cpp %}
#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
NumericVector ouch() {
  NumericVector x(10);
  x[1000000] = 1;
  return x;
}

/*** R
ouch()
*/
{% endhighlight %}

Now, let's run the script with R + `valgrind`.
If you're on OS X, you'll want an extra `valgrind` flag
to ensure that you get line numbers in the error
th the command line invocation:

    R --vanilla -d "valgrind --dsymutil=yes" -e "Rcpp::sourceCpp('segfault.cpp')"
    
Otherwise, you can just write

    R --vanilla -d valgrind -e "Rcpp::sourceCpp('segfault.cpp')"

Here's the beautiful mess I get:

    kevin:~/scratch$ R --vanilla -d "valgrind --dsymutil=yes" -e "Rcpp::sourceCpp('segfault.cpp')"
    ==93684== Memcheck, a memory error detector
    ==93684== Copyright (C) 2002-2013, and GNU GPL'd, by Julian Seward et al.
    ==93684== Using Valgrind-3.11.0.SVN and LibVEX; rerun with -h for copyright info
Rcpp::sourceCpp('segfault.cpp')
    ==93684== 
    --93684-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option
    --93684-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 2 times)
    --93684-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 4 times)
    ==93684== Warning: ignored attempt to set SIGUSR2 handler in sigaction();
    ==93684==          the SIGUSR2 signal is used internally by Valgrind
    --93684-- UNKNOWN host message [id 412, to mach_host_self(), reply 0x317]
    --93684-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 8 times)
    --93684-- UNKNOWN host message [id 222, to mach_host_self(), reply 0x317]
    --93684-- UNKNOWN mach_msg unhandled MACH_SEND_TRAILER option (repeated 16 times)
    
    R Under development (unstable) (2015-04-05 r68149) -- "Unsuffered Consequences"
    Copyright (C) 2015 The R Foundation for Statistical Computing
    Platform: x86_64-apple-darwin14.1.0 (64-bit)
    
    R is free software and comes with ABSOLUTELY NO WARRANTY.
    You are welcome to redistribute it under certain conditions.
    Type 'license()' or 'licence()' for distribution details.
    
      Natural language support but running in an English locale
    
    R is a collaborative project with many contributors.
    Type 'contributors()' for more information and
    'citation()' on how to cite R or R packages in publications.
    
    Type 'demo()' for some demos, 'help()' for on-line help, or
    'help.start()' for an HTML browser interface to help.
    Type 'q()' to quit R.
    
    > Rcpp::sourceCpp('segfault.cpp')
    --93684-- run: /usr/bin/dsymutil "/private/var/folders/m7/_xnnz_b53kjgggkb1drc1f8c0000gn/T/RtmprMe5q8/sourcecpp_16df452bf2ffd/sourceCpp_84035.so"
    
    > ouch()
    ==93684== Invalid write of size 8
    ==93684==    at 0x11A4C12E3: ouch() (segfault.cpp:7)
    ==93684==    by 0x11A4C13B7: sourceCpp_83425_ouch (segfault.cpp:23)
    ==93684==    by 0x10008A5E6: do_dotcall (dotcode.c:1251)
    ==93684==    by 0x1000B5F2B: Rf_eval (eval.c:655)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000B6066: Rf_eval (eval.c:674)
    ==93684==    by 0x10011150F: do_eval (eval.c:2471)
    ==93684==    by 0x1000C88C8: bcEval (eval.c:5482)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000C7509: bcEval (eval.c:5454)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==  Address 0x11a9ee678 is not stack'd, malloc'd or (recently) free'd
    ==93684== 
    
     *** caught segfault ***
    address 0x0, cause 'memory not mapped'
    
    Traceback:
     1: .Primitive(".Call")(<pointer: 0x11a4c1340>)
     2: ouch()
     3: eval(expr, envir, enclos)
     4: eval(ei, envir)
     5: withVisible(eval(ei, envir))
     6: source(file = srcConn, echo = TRUE)
     7: Rcpp::sourceCpp("segfault.cpp")
    aborting ...
    --93684-- VALGRIND INTERNAL ERROR: Valgrind received a signal 11 (SIGSEGV) - exiting
    --93684-- si_code=1;  Faulting address: 0x7000028A6400;  sp: 0x700000aa9af8
    
    valgrind: the 'impossible' happened:
       Killed by fatal signal
    
    host stacktrace:
    ==93684==    at 0x2380594FA: ???
    ==93684==    by 0x2380BE6BD: ???
    ==93684==    by 0x2380B5044: ???
    ==93684==    by 0x2380B3C90: ???
    ==93684==    by 0x2380B1CA1: ???
    ==93684==    by 0x2380C2DC6: ???
    
    sched status:
      running_tid=1
    
    Thread 1: status = VgTs_Runnable
    ==93684==    at 0x101F9FC82: __kill (in /usr/lib/system/libsystem_kernel.dylib)
    ==93684==    by 0x11A4C13B7: sourceCpp_83425_ouch (segfault.cpp:23)
    ==93684==    by 0x10008A5E6: do_dotcall (dotcode.c:1251)
    ==93684==    by 0x1000B5F2B: Rf_eval (eval.c:655)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000B6066: Rf_eval (eval.c:674)
    ==93684==    by 0x10011150F: do_eval (eval.c:2471)
    ==93684==    by 0x1000C88C8: bcEval (eval.c:5482)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000C7509: bcEval (eval.c:5454)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==    by 0x10010BEBC: forcePromise (eval.c:457)
    ==93684==    by 0x1000B5FE3: Rf_eval (eval.c:581)
    ==93684==    by 0x1001118A0: do_withVisible (eval.c:2500)
    ==93684==    by 0x10014FA40: do_internal (names.c:1350)
    ==93684==    by 0x1000C8BD4: bcEval (eval.c:5502)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000C7509: bcEval (eval.c:5454)
    ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000B6066: Rf_eval (eval.c:674)
    ==93684==    by 0x10010F812: do_begin (eval.c:1716)
    ==93684==    by 0x1000B615D: Rf_eval (eval.c:627)
    ==93684==    by 0x1000B615D: Rf_eval (eval.c:627)
    ==93684==    by 0x10010F812: do_begin (eval.c:1716)
    ==93684==    by 0x1000B615D: Rf_eval (eval.c:627)
    ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
    ==93684==    by 0x1000B6066: Rf_eval (eval.c:674)
    ==93684==    by 0x10014128E: Rf_ReplIteration (main.c:258)
    ==93684==    by 0x100142732: run_Rmainloop (main.c:308)
    ==93684==    by 0x100000F3A: main (in /Library/Frameworks/R.framework/Resources/bin/exec/R)
    
    Thread 2: status = VgTs_WaitSys
    ==93684==    at 0x101FA0136: __psynch_cvwait (in /usr/lib/system/libsystem_kernel.dylib)
    ==93684==    by 0x10067345D: blas_thread_server (in /usr/local/Cellar/openblas/0.2.13/lib/libopenblas_core2p-r0.2.13.dylib)
    ==93684==    by 0x1020B5267: _pthread_body (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B51E4: _pthread_start (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B341C: thread_start (in /usr/lib/system/libsystem_pthread.dylib)
    
    Thread 3: status = VgTs_WaitSys
    ==93684==    at 0x101FA0136: __psynch_cvwait (in /usr/lib/system/libsystem_kernel.dylib)
    ==93684==    by 0x10067345D: blas_thread_server (in /usr/local/Cellar/openblas/0.2.13/lib/libopenblas_core2p-r0.2.13.dylib)
    ==93684==    by 0x1020B5267: _pthread_body (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B51E4: _pthread_start (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B341C: thread_start (in /usr/lib/system/libsystem_pthread.dylib)
    
    Thread 4: status = VgTs_WaitSys
    ==93684==    at 0x101FA0136: __psynch_cvwait (in /usr/lib/system/libsystem_kernel.dylib)
    ==93684==    by 0x10067345D: blas_thread_server (in /usr/local/Cellar/openblas/0.2.13/lib/libopenblas_core2p-r0.2.13.dylib)
    ==93684==    by 0x1020B5267: _pthread_body (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B51E4: _pthread_start (in /usr/lib/system/libsystem_pthread.dylib)
    ==93684==    by 0x1020B341C: thread_start (in /usr/lib/system/libsystem_pthread.dylib)
    
    
    Note: see also the FAQ in the source distribution.
    It contains workarounds to several common problems.
    In particular, if Valgrind aborted or crashed after
    identifying problems in your program, there's a good chance
    that fixing those problems will prevent Valgrind aborting or
    crashing, especially if it happened in m_mallocfree.c.
    
    If that doesn't help, please report this bug to: www.valgrind.org
    
    In the bug report, send all the above text, the valgrind
    version, and what OS and version you are using.  Thanks.
    
Oh man! We killed R so hard that it even took
`valgrind` down with it. That hurts! Writing C and C++
code really is like playing with fire. But let's pull
out the pertinent output that `valgrind` gave us:

    > ouch()
        ==93684== Invalid write of size 8
        ==93684==    at 0x11A4C12E3: ouch() (segfault.cpp:7)
        ==93684==    by 0x11A4C13B7: sourceCpp_83425_ouch (segfault.cpp:23)
        ==93684==    by 0x10008A5E6: do_dotcall (dotcode.c:1251)
        ==93684==    by 0x1000B5F2B: Rf_eval (eval.c:655)
        ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
        ==93684==    by 0x1000B6066: Rf_eval (eval.c:674)
        ==93684==    by 0x10011150F: do_eval (eval.c:2471)
        ==93684==    by 0x1000C88C8: bcEval (eval.c:5482)
        ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
        ==93684==    by 0x10010C8E7: Rf_applyClosure (eval.c:1039)
        ==93684==    by 0x1000C7509: bcEval (eval.c:5454)
        ==93684==    by 0x1000B5CD5: Rf_eval (eval.c:558)
        ==93684==  Address 0x11a9ee678 is not stack'd, malloc'd or (recently) free'd
        ==93684== 

`valgrind` detects exactly where the invalid write 
occurred! It's caught that we attempted to perform an 
invalid write in our `ouch()` function, at line 7, 
exactly as we had known ourselves to be erroneously 
doing. In reality, we'll almost never know where
exactly we've introduced a bug or error, so this kind
of information is incredibly useful -- once we know
where to look, it is much, much easier to solve the
problem.

Now, how can you take this new-found information and
put it to work for yourself? In fact, you can do it
pretty easily. Let's suppose you're writing an R
package that contains some Rcpp code, and you're using
Hadley's [testthat](http://r-pkgs.had.co.nz/tests.html)
package to facilitate test running. If you're using
that infrastructure, then you should have a file at
the path `tests/testthat.R` which mediates running
of tests for you. If you want to run the tests with
`valgrind`, then all you need to do is,
_from the `tests` directory_, run:

    R -d valgrind -f testthat.R

And R will merrily go along running all your tests as
normal, but with the extra output from `valgrind` to
help you debug any segfaults you're encountering in
your own code. Awesome! In general, if you need to run
an R script, or R code, with `valgrind` it really is
as simple as making a regular command line invocation of
R, but with the `-d valgrind` flag added in.

It would be remiss of me to not mention
[R-exts](http://cran.r-project.org/doc/manuals/r-release/R-exts.html)
in this post. `R-exts` is a massive beast, and it's
very difficult to search for information within unless
you already know where it is, but the information
shared on debugging R code with tools like `valgrind`,
`gdb` and `lldb` is incredibly useful. If you're
interested in learning more, please read the sections:

- [4.3.1 - Using gctorture](http://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-gctorture)
- [4.3.2 - Using valgrind](http://cran.r-project.org/doc/manuals/r-release/R-exts.html#Using-valgrind)
- [4.4 - Debugging Compiled Code](http://cran.r-project.org/doc/manuals/r-release/R-exts.html#Debugging-compiled-code)

And, good luck!
