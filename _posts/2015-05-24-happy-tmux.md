---
layout   : post
title    : Happy tmux
tags     : r
comments : true
---

I was recently introduced to the joys of
[`tmux`](http://tmux.sourceforge.net/) by
a colleague, and felt like sharing a bit of
what I learned.

## What's tmux?

`tmux` is a **t**erminal **mul**tiplexer,
which is a fancy way of saying that `tmux`
manages multiple terminals for you -- and
it does a couple things for you, very well.

- It provides a 'window manager' for
  terminals -- you can view multiple terminals
  at the same time, with many options for
  tiling (e.g. vertical and horizontal splits,
  4-pane layouts, and so on)

- Persistent sessions, so you can start a 
  session at some time and re-attach to it at
  a later time. Incredibly useful when working
  remotely, e.g. when running code on a
  cluster, or otherwise 'remote' device.

## How do I install it?

If you're on a *nix distribution, you can
get `tmux` using your package manager; if
you're on OS X, I suggest using
[homebrew](http://brew.sh/) and performing
a simple `brew install tmux`.

## How do I use it?

You can launch `tmux` just by calling
`tmux` from your shell. After running that,
you should see a new shell, but with
`tmux`'s status bar at the bottom. Like `vim`,
`tmux` provides a lot of modal functionality
with a minimal amount of visual feedback;
ie, it assumes you know what you're doing.

![tmux-base]({{ site.baseurl }}/images/tmux-base.png)

When working with `tmux`, it's mostly like
working in any old plain terminal session --
ie, after starting `tmux`, you'll just be
planted into a shell and you can do things
as you normally would. The only difference
is the little status bar at the bottom:

However, by typing
a special **prefix** key, you can switch to
what I'll call `tmux-mode` and start
asking `tmux` to execute some commands.

By default, the prefix key combination is
`Ctrl + B`. If you're following along, try
executing these commands to create a `tmux`
session and then split your 'window':

    tmux
    <Ctrl + B> %

After doing this, you should see you now have
two terminals open, in a vertical split. Sweet!

![tmux-split]({{ site.baseurl }}/images/tmux-split.png)

You can then switch back-and-forth between these
two terminals with e.g.

    <Ctrl + B> <Right>  ## select right pane
    <Ctrl + B> <Left>   ## select left pane

What you're seeing now is, in `tmux` parlance, is
two **panes** in a single **window**. This is a bit
at odds with how we normally call these; e.g. I
would prefer to say we have two **windows** open
with a single **tab**, but it is what it is.

Let's try creating a new window (tab) and
navigating back and forth:

    <Ctrl + B> c ## 'c' for create
    <Ctrl + B> n ## 'n' for next
    <Ctrl + B> p ## 'p' for previous

You can also list the set of all available
windows with `<Ctrl + B> w` -- this gives you
a list of all available windows and select one
from there.
    
![tmux-windows]({{ site.baseurl }}/images/tmux-windows.png)

Now, we have a good 'sense' for how `tmux` works:

1. Type the prefix key,
2. Press a second key to perform from `tmux` action.

There's a lot of utility in having an editor
open in one pane, documentation in another,
and perhaps an active console in another.

There's plenty more to learn as far as `tmux`
keybindings and functionality goes, but I'll
leave most of that to your Google-fu, as well as
some links that I found particularly helpful:

- [Practical tmux](https://mutelight.org/practical-tmux)
- [Tools I use: tmux](https://justin.abrah.ms/dotfiles/tmux.html)

And, if you're on OS X, follow
[this link](https://robots.thoughtbot.com/tmux-copy-paste-on-os-x-a-better-future)
to get `tmux` to use the system clipboard.

## What's in my .tmux.conf?

`tmux` is similar to Emacs in that you're
generally encouraged to configure it to your
own taste.

## Alternatives: GNU screen

You might be familiar with
[`screen`](http://www.gnu.org/software/screen/):
`tmux` is a (newer) alternative with a much saner
configuration language, but there are still many
who swear by `screen`. In my (uneducated) opinion,
unless you're already very comfortable with `screen`,
you're better off learning and using `tmux`. If you're
curious, there was a [lively debate](https://news.ycombinator.com/item?id=7757812)
on Hacker News.
