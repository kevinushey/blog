---
layout   : post
title    : The RStudio macOS Rendering Bug
tags     : rstudio
comments : true
---

The RStudio v1.2 release is coming soon, and it's been a long time coming. RStudio v1.1 was first released on July 20th, 2017, making this now over a year and a half since its release. We originally intended for this to be a somewhat shorter release, but (as these things happen) we ended up transitioning some work originally planned for RStudio v1.3 to RStudio v1.2.

One of the work items we had for RStudio v1.2 was a Qt update. Previous versions of RStudio built against Qt 5.4 (an ancient version that was not even a long-term support release!), and depended on a Qt component (QtWebKit) which had since been deprecated and replaced with a newer component (QtWebEngine). The goal was to update to the latest long-term support release of Qt (5.9 at the time), and port our QtWebKit-using code to QtWebEngine. This ended up being a far larger endeavour than any of us suspected it could be at the time.

On its face, the update looked challenging, but doable. Most of the QtWebKit classes and functions had QtWebEngine analogs (e.g. what used to be `QWebPage` would become `QWebEnginePage`), and Qt even provided a helpful [porting guide](https://wiki.qt.io/QtWebEngine/Porting_from_QtWebKit) for some of the pieces that were missing. One added challenge was that it would no longer be able to synchronously execute JavaScript code and retrieve its result, and we did rely on that in a few places -- but still, this was surmountable.

What we were not ready for were the bugs. If you're curious, the family of QtWebEngine bugs we tagged and dealt with are available [here](https://github.com/rstudio/rstudio/issues?q=label%3Aqtwebengine+is%3Aclosed); suffice to say there were a litany of bugs (some our own, some Qt's) that we had to either fix or work around. While our goal was to use and depend on the Qt 5.9 LTS, we encountered a number of issues that we couldn't work around ourselves yet found were fixed in the newer releases of Qt (5.10, 5.11, 5.12). Infrastructure changes like these are typically something you want to accomplish close to the start of a release cycle (since, as we expected, there would be issues to solve) and yet each release of Qt seemed to bring some kind of new show-stopping issue that gave us no choice but to again update (and so again take on the risks with updating)

I want to say in advance: I don't mean to be too hard on the Qt team here. They're maintaining an absolutely massive software project that spans a gigantic matrix of environments, which they still distribute for free as open-source software. It's our duty as users of Qt to help test their software and give back when possible. And, the Qt team has (in our experience) been quick to fix the more major issues we've reported, or at least help catalogue workarounds when a fix was unable to become part of a particular release. So even though the transition to Qt WebEngine has been challenging, we are still incredibly thankful for their work.

## The macOS Rendering Bug

This post, then, is about one Qt bug in particular -- the [macOS rendering bug](https://github.com/rstudio/rstudio/issues/4409). In effect, users of RStudio on Sierra / High Sierra would see:

1. When RStudio first started, the window was blank;
2. When the RStudio window was resized, the contents would be 'stretched' incorrectly relative to the bounds of the window.

![RStudio macOS rendering issue]({{ site.baseurl }}/images/rstudio-skewed.png)

This, unfortunately, was a bug we were seeing when attempting to update from Qt 5.11 to Qt 5.12, and we were determined to update to Qt 5.12 on macOS to gain access to other fixes that had made their way into this release. 
## Searching Blindly

My first hypothesis was that we were bumping into some kind of macOS SDK compatibility issue with Qt. I had observed the following:

1. The issue _did not_ occur with local builds I made on my macOS 10.14 (Mojave) machine;
2. The issue _did_ occur with the builds produced from our 'build farm', which was a macOS 10.12 (Sierra) machine.

So the first step was to try updating the macOS builder to Mojave, and then try to produce builds (using 10.12 as our deployment target). Unfortunately, after this we saw the converse: users running Mojave no longer saw the rendering issue, but now users running Sierra and High Sierra did see the issue!

I then thought that, perhaps, we might have better luck with our own Qt builds (as opposed to the official Qt builds). Unfortunately, these locally-produced Qt builds had RStudio exhibiting the same issue.

## Stepping Back

So, we had no choice but to try to dive in. But how do you diagnose an issue like this? The first step was to step back, and take a deep breath. Without any obvious strings to pull, the first thing we can do is *collect information*.

- What do we know?
- What don't we know?
- What can we learn?

In particular, it's helpful to try and catalog all of the cases where the bug *does* occur, and the cases where the bug *does not* occur. If we can collect enough information on each side, then we can use the difference to find out which code paths are worth exploring.

## Gathering Information

We started with one useful bit of information: the problem only occurred when hardware-accelerated rendering was turned on. Users who activated software rendering did not see this problem. This appeared to be true regardless of the machine (or GPU) RStudio was running on. So, we were almost certainly (inadvertently?) doing something that was affecting how the GPU was being used to render the RStudio UI.

With that in mind, my first instinct was to consult the [Chromium flags](https://peter.sh/experiments/chromium-command-line-switches/) to see if there might be some magic GPU-related switch that could help resolve this behavior. This hunch was primarily motivated by the fact that there was indeed a magic switch that helped us resolve an [entirely separate rendering issue](https://github.com/rstudio/rstudio/issues/1953). Unfortunately, this was a dead end: none of the switches would help.

The next question to ask was, "do other Qt WebEngine applications exhibit this behavior?" Fortunately, Qt itself comes with a number of examples, including its own version of a simple web browser (called Nano Browser) built upon Qt WebEngine. Somewhat to my surprise, the example applications did _not_ exhibit this issue. At least this told us that there was something specifically we were doing in RStudio that was causing this issue, as opposed to something inherent to Qt 5.12 that we wouldn't be able to work around.

The next thing I sought to see was whether _all_ RStudio windows exhibited this issue. I then discovered that while the main RStudio window and popped-out Source windows exhibited the issue, but others (e.g. the Git Review Changes window; the 'Zoom' plot window) did not. Furthermore, if we told RStudio to just load a blank webpage (rather than the main IDE surface) the issue did not occur. So, it appeared that we were doing something special in these windows that caused the issue to manifest.

## The Lightbulb Moment

We're getting closer, but we're still not quite there yet. At this point, I'm just repeatedly launching RStudio, observing the bug (blank window on launch; rendering issues on window resize) and hoping that something else will click. That's when I finally noticed something subtle.

Here's a GIF of what I was seeing when RStudio was launched.

![RStudio Startup]({{ site.baseurl }}/images/macos-rendering.gif)

Do you notice anything? It took a while for this to click, but there was another piece of the puzzle here. It's obvious in hindsight, but with 'bug blinders' on it didn't register immediately. It was this:

*The window was not actually blank on startup!*

We were successfully rendering the loading indicator, and we even (for a single frame) managed to render the RStudio UI successfully. In other words, the RStudio UI rendered successfully, and then something happened on startup to break rendering.

## Putting it Together

Now, we know:

1. The issue only affects RStudio when hardware acceleration is enabled;
2. The issue only occurs in the main RStudio window / Source window;
3. The issue doesn't occur immediately; it only occurs after the first bit of RStudio initialization had completed.

We've finally narrowed this bug down to somewhere reasonable to look. What code runs after RStudio has first finished initialization, and only runs in the main RStudio window / Source window? This finally lets us narrow down the bug to a reasonable subset of code in the RStudio code base.

This is where I get a bit lucky. My hunch was that, because the main / source windows are the only RStudio windows where we load the Ace editor, the issue must lie within some of the code we use to manage Ace. I then tested Ace and confirmed that it worked just fine in the Nano Browser example, so I knew it had to be something _we_ were doing with Ace. One place where we do a lot of custom work is with Ace themes, so my first hunch was to try disabling the theme-related work we do on initialization:

<https://github.com/rstudio/rstudio/blob/5dbb093eff0be140c45298ab645f85a9347279c2/src/gwt/src/org/rstudio/studio/client/application/Application.java#L767-L768>

And, to my amazement, removing that line of code fixed the issue! So we finally have a code path that we can dive into to look for the issue. It was then a few bouts of code surgery (remove a few lines of code here and there to see what happens) to get to the true culprit:

<https://github.com/rstudio/rstudio/blob/5dbb093eff0be140c45298ab645f85a9347279c2/src/cpp/desktop/DesktopGwtCallbackMac.mm#L473-L475>

```
view.wantsLayer = YES;
```

In other words, some code we had introduced recently to change the background color in the toolbar was ultimately responsible for this issue. Now, with the benefit of hindsight, we can start looking into what side-effects `view.wantsLayer = YES;` might have that could cause this issue.

## Post-Mortem

Phew. We've figured out the bug, and we've figured out a fix. We've now also learned that this is not really a Qt bug per-se -- rather, it's a bad interaction between Qt and an NSWindow API we used to control how windows are rendered. However, it's worth stepping back and evaluating how we could've either prevented this bug in its entirety, or more efficiently found a fix as this bug had haunted us for quite a few months.

Firstly, the Apple Developer documentation makes it quite clear that `view.wantsLayer` [affects how a window is rendered](https://developer.apple.com/documentation/appkit/nsview/1483695-wantslayer):

> Setting the value of this property to true turns the view into a layer-backed view—that is, the view uses a CALayer object to manage its rendered content. Creating a layer-backed view implicitly causes the entire view hierarchy under that view to become layer-backed. Thus, the view and all of its subviews (including subviews of subviews) become layer-backed. The default value of this property is false.

Had I known / recalled this, it might've been easier to simply think, "in what parts of the code do we mess with how things are rendered?" but I did not have that in the forefront of my mind.

Next, we can see in the [AppKit release notes](https://developer.apple.com/documentation/macos_release_notes/macos_mojave_10_14_release_notes/appkit_release_notes_for_macos_10_14):

> Windows in apps linked against the macOS 10.14 SDK are displayed using Core Animation when the app is running in macOS 10.14. This doesn’t mean that all views are layer-backed; rather, it means that all views are either layer-backed or draw into a shared layer with other layers.

This would've been yet another hint that, at least, the way things are rendered has changed in Mojave (and so messing with that across different versions of macOS may not be advisable).

Finally, we can then see that other users had reported similar incantations of this issue to Qt:

<https://bugreports.qt.io/browse/QTBUG-70340>
<https://bugreports.qt.io/browse/QTBUG-69321>

And so others had seen, with hardware-accelerated windows, issues when playing with the `wantsLayer` flag.

This bit of code was originally contributed by a pull request by [@randy3k](https://github.com/randy3k):

<https://github.com/rstudio/rstudio/pull/3369>.

Note: I'm not trying to point fingers here; I'm the one who merged the PR! It's my fault for not thinking through the potential repercussions of making that change. In hindsight, it's easy to say "maybe setting a flag that changes how windows are rendered could bite us down the line". Or, had I read the Apple documentation beforehand, this code path might've seemed a more obvious culprit earlier.

## Summing Up

In sum, I think these are the two biggest lessons for me:

1. For each line of code in your code base, you should understand which components of your application could be affected by it -- especially for flags or toggles that affect some sort of application-wide behaviour. For something like this, where we're setting a flag that alters how the application is rendered, it would've been nice to have that parked in the back of my mind when I first sought to fix this issue.

2. For any bug, no matter how insurmountable it may seem at first look, the best first step is to collect information. When does the bug occur, and when does it not occur? Given enough information on each side, the diff will eventually point towards the code paths that are worth scrutinizing.

With this fix in, we are finally getting close to preparing a final release for RStudio v1.2. It's not perfect (no release ever is!) but I believe we've made some substantial improvements relative to v1.1. In particular, RStudio v1.2 should be much more responsive, especially for users with high DPI displays (see [the laggy typing issue](https://github.com/rstudio/rstudio/issues/1539) for even more context there). If you're eager to get your hands on RStudio v1.2, a [preview release](https://www.rstudio.com/products/rstudio/download/preview/) is available and that release is very close to what will eventually become our final release candidate, so please feel free to give it a spin.


