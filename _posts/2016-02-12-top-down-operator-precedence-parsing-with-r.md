---
layout   : post
title    : Top-Down Operator Precedence Parsing with R
tags     : r
comments : true
---

Parsers are a topic that have been brewing in the back of my
head for a while now. Mainly, "how do I write one?" and "I 
really want to write one!". There's something very ... zen, 
about the idea of writing a program that understands how to 
read and interpret another program.

However, I've found parser theory to be fairly hard to
understand -- it's been like fitting a square peg into a
round brain for me. It doesn't help
that the existing literature is [quite technical](https://en.wikipedia.org/wiki/Compilers:_Principles,_Techniques,_and_Tools#Second_edition),
and (IMHO) there is not much accessible literature that
attempts to bridge the gap between formal computer science
and software engineering. It also doesn't help that parsers
are widely considered a solved problem in computer science,
so many aren't really interested in talking about them 
anymore -- just throw
[flex](https://en.wikipedia.org/wiki/Flex_lexical_analyser)
and [bison](https://en.wikipedia.org/wiki/GNU_bison) at your
language and call it a day.

However, I first gained hope that I might one day be able to
write my own parser, when I learned about
[recursive descent parsing](https://en.wikipedia.org/wiki/Recursive_descent_parser).
These are relatively simple to understand, as long as
you can write down a specification of your language in
[Extended Backus-Naur Form](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_Form).
EBNF is used to describe a language with a set of rules, 
which read quite naturally. For example, we could have a 
rule for R function definitions written as:

    <function>: 'function' '(' <arg-list> ')' <expression>

where `<arg-list>` and `<expression>` are also rules 
defining what an argument list and an expression can look 
like, respectively. In other words, a function in the R 
language is specified first with a `function` token, then 
with an opening parenthesis `(` token, then with a (possibly
empty) argument list, which is then enclosed by a closing 
parenthesis `)` token, which is finally followed by a
(non-empty) function body expression.

Given this, we could write the following pseudo-ish code to
parse the function. `check()` is used to validate a token's
contents, and then advance (behind the scenes) to the next
token.


{% highlight r %}
parseFunction <- function() {
  check("function")
  check("(")
  arglist <- parseArgList()
  check(")")
  body <- parseExpression()
  call("function", arglist, body)
}
{% endhighlight %}

Don't think too much about how the above is implemented, 
just focus on the code's structure. The routine walks over 
tokens, checking them as it goes, and calls parse
subroutines to get the argument list + expression as
necessary. The point I want to make here is that the code
you write when implementing a recursive-descent parser
mimics the EBNF grammar very closely -- this is a very nice
property, which makes the parser very easy to write and
reason about. I promise that the code you would write, or
see, in a true implementation would be very similar to this.

Unfortunately, recursive descent becomes quite clumsy when 
it comes to handling operator precedence (e.g. expressing 
that `/` and `*` have higher precendece than `+` and `-`). 
In a recursive-descent context, this is handled by having a 
separate rule for each operator precedence level, e.g. in 
defining `<expr>`, we would have to write something like:

    <expression> = ["+"|"-"] <term> {("+"|"-") <term>} .
    <term>       = <factor> {("*"|"/") <factor>} .
    <factor>     = <symbol>
                 | <number>

This implies having these (in my mind, bogus) names that 
differentiate what the rule handling `+` and `-`s is, and 
the rule handling `*` and `/` is. This also implies a 
separate function for each of these rules (e.g.
`parseTerm()`, `parseFactor()`). You could imagine this
being a huge pain -- for example, in R, we have 18 different
operator groups + precedence classes. Do you want to write
18 different functions for parsing each of these? I
certainly don't! It also implies our parser will be
inefficient, as parsing an operator can require deep
recursions until the appropriate rule is found.

With that, I had somewhat given up hope on recursive-descent
parsing. It's obviously _doable_ to implement an entirely
recursive-descent based parser for a language, but it's 
boring, unwieldy, and slow.

And then I discovered **top-down operator precedence (TDOP)**
parsers (also called [Pratt parsers](https://en.wikipedia.org/wiki/Pratt_parser),
named for Vaughan Pratt, who introduced this in his 1973 paper [Top-Down Operator Precedence](http://dl.acm.org/citation.cfm?id=512931).)
This is a parsing technique that handles operator
precedence, both unary and binary, in an extremely elegant,
clean, and performant fashion. I stumbled upon it when I
learned about
[JSLint](https://en.wikipedia.org/wiki/JSLint) (a program
that identifies 'code smells' in JavaScript programs) and
the [article in which Douglas Crockford](http://javascript.crockford.com/tdop/tdop.html) 
describes how he used top-down operator precedence parsing 
to implement it.

However, Crockford's article rubs me the wrong way in a few 
places, with the use of technical terms like `led` ('left
denotation') and `nud` ('null denotation') which are opaque
enough that my brain hiccups whenever I see them. That said,
even if my blog post is (hopefully) a more accessible 
introduction, I highly recommend that you read Crockford's 
article next. Alternatively (hat tip to [@tjmahr](https://twitter.com/tjmahr)), you
can watch Douglas Crockford's recent video [Syntaxation](https://www.youtube.com/watch?v=Nlqv6NtBXcA),
where he discusses TDOP parsing (we share a similar love
of the core of TDOP).

I think the core concepts behind TDOP parsers can be 
expressed much more plainly. So, here goes. In a language, 
there are two kinds of symbols:

1. Symbols that 'start' an expression (S), and
2. Symbols that 'continue' an expression (C).
   
For example, given the program below we could denote the symbols:

    - x + y * - 4
    S S C S C S S

Note that both unary operators and variables can be
encountered at the start of an expression. The binary
operators `+` and `*` serve to continue, or join, the
expression (such that the program above is indeed a single
expression). Whether an operator is considered unary or
binary depends on whether it's encountered at the 'start' or
'middle' of an expression.

We're going to have two functions for handling parses in the
'start' and 'continue' states -- I'll name them now, but
we'll develop implementations later.

- `parseExpressionStart()`: parse routine for tokens that 'start' expressions,
- `parseExpressionContinuation()`: parse routine for tokens that 'continue' expressions.

Armed with this basis, let's consider how we could write a 
parser for a super simple calculator language. In our 
language, we will have integers `[0-9]+`, and the binary 
operators `+` and `*`, where `*` has a higher precedence 
than `+`. It's a tiny language, but has just enough to
force us to properly handle operator precedence, and once
that's a solved problem, everything else will fall out
naturally.

Unfortunately, we can't implement a parser without a 
tokenizer, so let's get this out of the way first. Briefly, 
a tokenizer splits a program (as a string) into the base 
syntactic elements (tokens) that make up the language. We'll
have three functions that handle tokenization:

- `tokenize()`: takes a program as a string, and returns a tokenized representation,
- `current()`: returns the current active token, and
- `consume()`: returns the current token, and also advances the token index.

Let's implement a simple, crude tokenizer:


{% highlight r %}
# Global state. Icky, I know, but keeps it simple.
tokens <- c()
index <- 0

# Tokenize our document by splitting on whitespace.
tokenize <- function(program) {
  tokens <<- unlist(strsplit(program, "\\s+"))
  index  <<- 1
  tokens[index]
}

# Get the current token.
current <- function() {
  tokens[index]
}

# Get the current token, and advance to the next.
consume <- function() {
  token <- current()
  index <<- index + 1
  token
}

# Exercise the tokenizer
program <- "1 + 2 * 3 + 4 * 5 + 6"
tokenize(program)
{% endhighlight %}



{% highlight text %}
[1] "1"

{% endhighlight %}



{% highlight r %}
c(consume(), consume(), consume())
{% endhighlight %}



{% highlight text %}
[1] "1" "+" "2"

{% endhighlight %}

Clunky, but this will be enough to power our parser. So
let's get back to the fun stuff.

Now, I'm going to show you the top-level parse routine. Hold
on to something, because this is going to be rad. With
operator-precedence parsing, our parse routine can be
expressed in an incredibly simple, elegant form. Honestly,
it's one of the most elegant ways of solving a problem that
I've ever seen -- I don't often call algorithms beautiful,
but this one is. We can implement our top-level parse
routine in just 4 lines of code:


{% highlight r %}
parseExpression <- function(precedence = 0) {
  node <- parseExpressionStart()
  while (precedence < binaryPrecedence(current()))
    node <- parseExpressionContinuation(node)
  node
}
{% endhighlight %}

This is the engine that gives us a parser that understands 
binary precedence. Seriously. Yes, a single function with a 
4-line function body and we have something that will be able
to understand binary precedence. We've escaped from the
recursion hell that pure recursive-descent parsers have when
attempting to handle operator precedence. Even more, this
basis will handle new extensions to our language with no
problem at all, as you'll see later. This is the holy grail
upon which we can build our parser, and everything will just
come together cleanly.

Let's ignore how it works for now, and just assume that it 
will work. Now, let's talk about our supporting cast. First,
`parseExpressionStart()`. For our simple calculator, the 
only syntactic element in the language that can occur at the
start of an expression is an integer (we don't have unary 
operators yet), so we just accept that:


{% highlight r %}
parseExpressionStart <- function() {
  token <- consume()
  as.numeric(token)
}
{% endhighlight %}

Next, our parse routine for things that continue an 
expression -- for our simple calculator, this is either a 
`+` or a `*`. The key part is that this routine will
generate a `call()` object, with the current binary operator
as the 'head', the node passed in as the first child, and
the result of a recursive call to `parseExpression()` as the
second child. Note that we pass down the binary precedence
of that operator as well:


{% highlight r %}
parseExpressionContinuation <- function(node) {
  token <- consume()
  call(token, node, parseExpression(binaryPrecedence(token)))
}
{% endhighlight %}

Finally, our `binaryPrecedence()` function will report the
precedence of a binary operator. We include the default `0`
case to handle when we reach the end of our input stream --
this signals the parse engine to stop trying to continue, or
join, expressions.


{% highlight r %}
binaryPrecedence <- function(token) {
  switch(token, "+" = 10, "*" = 20, 0)
}
{% endhighlight %}

Now, let's put this all together with a working example. The
following chunk is a complete implementation of the parser
for our simple calculator program, and the implementation 
isn't even 50 lines of code!


{% highlight r %}
tokens <- c()
index <- 0

tokenize <- function(program) {
  tokens <<- unlist(strsplit(program, "\\s+"))
  index <<- 1
  tokens
}

current <- function() {
  tokens[index]
}

consume <- function() {
  token <- current()
  index <<- index + 1
  token
}

parseExpressionContinuation <- function(node) {
  token <- consume()
  call(token,
       node,
       parseExpression(binaryPrecedence(token)))
}

# Parsing routine that is executed for syntactic
# elements that can begin an expression. For our
# simple calculator, this is just the number as-is.
parseExpressionStart <- function() {
  token <- consume()
  as.numeric(token)
}

# The parse engine, beautiful and glorious in its
# simplicity. Given a precedence 'precedence',
# parses an expression.
parseExpression <- function(precedence = 0) {
  node <- parseExpressionStart()
  while (precedence < binaryPrecedence(current()))
    node <- parseExpressionContinuation(node)
  node
}

# Our entry-point for parsing programs.
parse <- function(program) {
  tokens <<- tokenize(program)
  index <<- 1
  parseExpression()
}

# Run it!
program <- "1 + 2 * 3 + 4 * 5 + 6"
ast <- parse(program)
ast
{% endhighlight %}



{% highlight text %}
1 + 2 * 3 + 4 * 5 + 6

{% endhighlight %}



{% highlight r %}
eval(ast) == 1 + 2 * 3 + 4 * 5 + 6
{% endhighlight %}



{% highlight text %}
[1] TRUE

{% endhighlight %}

God, I love it! It may be a simple language, but with less
than 50 lines of code we have a fully functioning parser.

Now, let's think a bit about how it all works. Let's trace
out what happens when we get a `parseExpression()` call.
Let's look at our engine, but let's trace what happens
behind the scenes using R's `trace()` function.


{% highlight r %}
# A tracer that prints the context for each call.
# Ignore the ugliness.
n <- length(sys.calls())
tracer <- quote({
  indent <- paste(rep.int("", length(sys.calls()) - n - 5), collapse = "    ")
  output <- capture.output(print(sys.call(sys.parent(4))))
  cat("(", current(), "): ", indent, output, "\n", sep = "")
})

# Apply tracers
invisible(trace(parseExpression, tracer, print = FALSE))
invisible(trace(parseExpressionStart, tracer, print = FALSE))
invisible(trace(parseExpressionContinuation, tracer, print = FALSE))

# Run our parser
parse("1 + 2 * 3 + 4")
{% endhighlight %}



{% highlight text %}
(1): parseExpression()
(1):     parseExpressionStart()
(+):     parseExpressionContinuation(node)
(2):         parseExpression(binaryPrecedence(token))
(2):             parseExpressionStart()
(*):             parseExpressionContinuation(node)
(3):                 parseExpression(binaryPrecedence(token))
(3):                     parseExpressionStart()
(+):     parseExpressionContinuation(node)
(4):         parseExpression(binaryPrecedence(token))
(4):             parseExpressionStart()

{% endhighlight %}



{% highlight text %}
1 + 2 * 3 + 4

{% endhighlight %}



{% highlight r %}
# Clean up
untrace(parseExpression)
untrace(parseExpressionStart)
untrace(parseExpressionContinuation)
{% endhighlight %}

It's pretty nifty that the tracer output basically mimics 
the structure of the actual AST that we receive at the end. 
The main thing to notice is how the recursion begins, and 
ends -- starting at the first 
`parseExpressionContinuation()`, note that the `*` call 
becomes a child of that node. Because `*` has a higher 
precedence, it binds more tightly, and so it indeed binds 
`2` rather than letting `+` take it. Similarly, the `*` gets
ownership of `3` over the following `+` operator. It's still
tough for me to wrap my head around it, but this helps.

Let's now start extending our language. The foundations are
solid enough that we can easily extend our parser. Let's
first start by making our parser more generic -- we'll
abstract out the concept of operators and precedence:

1. We'll create a `PRECEDENCE` object that maps the set of
   available unary and binary operators, and associates
   them with a precedence,

2. We'll have separate `unaryPrecedence()` and `binaryPrecedence()`
   functions for retrieving these precedences, and

3. We'll augment our `parseExpressionStart()` function to handle
   unary operators.


{% highlight r %}
# Store a precedence table, that maps unary and
# binary operators to their associated precedences.
PRECEDENCE <- list(
  unary = list("+" = 100, "-" = 100),
  binary = list("+" = 10, "-" = 10,
                "*" = 20, "/" = 20)
)

# Get the precedence of a unary operator.
unaryPrecedence <- function(token) {
  if (token %in% names(PRECEDENCE$unary))
    PRECEDENCE$unary[[token]]
  else
    0
}

# Get the precedence of a binary operator.
binaryPrecedence <- function(token) {
  if (token %in% names(PRECEDENCE$binary))
    PRECEDENCE$binary[[token]]
  else
    0
}

parseExpressionContinuation <- function(node) {
  token <- consume()
  call(token,
       node,
       parseExpression(binaryPrecedence(token)))
}

# Note that our 'parseExpressionStart()' now
# accepts both unary operators (by checking the
# precedence table) as well as plain numbers.
parseExpressionStart <- function() {
  token <- consume()
  if (token %in% names(PRECEDENCE$unary))
    call(token, parseExpression(unaryPrecedence(token)))
  else
    as.numeric(token)
}

parseExpression <- function(precedence = 0) {
  node <- parseExpressionStart()
  while (precedence < binaryPrecedence(current()))
    node <- parseExpressionContinuation(node)
  node
}

# Run it!
program <- "- + 1 + - 2 * 3 / + 4 * 5 / + + + - - - 6"
ast <- parse(program)
ast
{% endhighlight %}



{% highlight text %}
-+1 + -2 * 3/+4 * 5/+++---6

{% endhighlight %}



{% highlight r %}
eval(ast) == eval(base::parse(text = program))
{% endhighlight %}



{% highlight text %}
[1] TRUE

{% endhighlight %}

We've extended our language to handle unary operators,
as well as the operators `*` and `/`. Something that's
even cooler is, since our parser is now entirely powered
by the precedence table, we could even modify that
table _at run time_ to introduce new syntax into the
language. Look, `|>` is an operator now!


{% highlight r %}
PRECEDENCE$binary[["|>"]] <- 5
program <- "1 |> 2 |> 3"
parse(program)
{% endhighlight %}



{% highlight text %}
`|>`(`|>`(1, 2), 3)

{% endhighlight %}

That's goddamn rad.

What about control flow and custom forms, you ask? What
if I want to turn my calculator into a real programming
language? These fit easily as well, and this is where our
recursive-descent style routines come in. The key thing
to realize is that these control flow constructs are just
special things that can 'start' an expression. So, they
need code that lives in `parseExpressionStart()`. Here's
what that might look like for an R `while` loop:


{% highlight r %}
# Checks and consumes on success
check <- function(token) {
  stopifnot(token == consume())
}

parseWhile <- function() {
  check("(")
  condition <- parseExpression()
  check(")")
  expression <- parseExpression()
  call("while", condition, expression)
}

parseExpressionStart <- function() {
  token <- consume()
  if (token == "while")
    parseWhile()
  else if (token %in% names(PRECEDENCE$unary))
    call(token, parseExpression(unaryPrecedence(token)))
  else
    as.numeric(token)
}

program <- "1 + while ( 1 ) 2 + 3"
parse(program)
{% endhighlight %}



{% highlight text %}
1 + while (1) 2 + 3

{% endhighlight %}

You know what? Let's go all out and make it possible to
add custom constructs _at runtime_!


{% highlight r %}
# Built-in constructs...
CONSTRUCTS <- list("while" = parseWhile)

# Add our own!
CONSTRUCTS[["unless"]] <- function() {
  check("(")
  condition <- parseExpression()
  check(")")
  expression <- parseExpression()
  call("unless", condition, expression)
}

# Augment our 'parseExpressionStart()' function to
# accept custom constructs.
parseExpressionStart <- function() {
  token <- consume()
  if (token %in% names(CONSTRUCTS))
    CONSTRUCTS[[token]]()
  else if (token %in% names(PRECEDENCE$unary))
    call(token, parseExpression(unaryPrecedence(token)))
  else
    as.numeric(token)
}

program <- "unless ( 1 ) 2 * 3"
parse(program)
{% endhighlight %}



{% highlight text %}
unless(1, 2 * 3)

{% endhighlight %}

We now have a mechanism for _building a language at runtime_.
Mind-blowing! You could imagine taking this to the logical
extreme and implementing an R parser -- *in R* -- with your
own runtime extensions.

Hopefully after walking through with me, you can see just
how exciting and awesome Pratt parsers truly are. Simple,
elegant, extensive, and performant... these are, in my mind,
the unicorns of the parser world, and it's no surprise that
`gcc` and `clang` use their own custom-built parsers built
with this same model.

What have I left out? There's a few things:

1. Left-associativity vs. right-associativity of operators,
2. Handling and reporting errors (give up? attempt to fix up and continue to parse?),
3. What signals the 'end' of an expression?
4. Function calls.

I'll direct you to the 'Further Reading' for 1), and your
own devices for 2), 3) and 4).

One thing you might notice about 3) is that our parser
doesn't actually care -- it could easily just parse `1 + 2 3
+ 4 5 + 6` as 3 separate expressions, but to be nice to the
programmer, we typically force expressions to be separated
with `;` or a newline or some other delimiter.

Finally, a hint for 4), though: you can either implement
your own custom parse routine for functions, or you can
treat `(` as a binary operator, with the restriction that it
must find an enclosing `)` when you finish parsing.

But honestly, this is the core of it -- the rest is your own
extensions. Parse on!

## Further Reading

This blog post is highly inspired by the following posts, but
of course presents its implementation in R.

- [Syntaxation](https://www.youtube.com/watch?v=Nlqv6NtBXcA): Douglas Crockford's talk re: TDOP.

- [Top Down Operator Precedence](http://javascript.crockford.com/tdop/tdop.html): Douglas Crockford's use of TDOP in JSLint.

- [Top-down Operator Precedence Parsing](http://eli.thegreenplace.net/2010/01/02/top-down-operator-precedence-parsing): TDOP in Python.

- [Simple Top-Down Parsing in Python](http://effbot.org/zone/simple-top-down-parsing.htm): More TDOP in Python.

- [TDOP / Pratt parser in pictures](http://l-lang.org/blog/TDOP---Pratt-parser-in-pictures/): A nice animated view of how the parse tree is built when using a Pratt parser.

- [Let's Build a Compiler](http://compilers.iecc.com/crenshaw/): An _excellent_ book on how one might construct a compiler for Pascal. It uses a (pure) recursive-descent parser, but also discusses emitting code and more.
