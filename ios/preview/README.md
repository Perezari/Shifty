# The iPhone app in the browser

`index.html` shows the iPhone app's screens on an iPhone 17 Pro of 402 by 874 points, scaled to fit,
before there is a build: the Now screen (a shift running, on a break, or none), the Lock Screen's Live
Activity, the Dynamic Island and the widgets, in light and dark. It is one page with made-up shifts (the
repository is public), published as a Claude artifact to open on the iPhone; it opens from the file in a
browser too.

A design is tried here first, and built once it is agreed: when a SwiftUI view changes, its counterpart
here changes with it. The clocks and the bar run as the app's do, from `Format.timer` and
`Calc.nowStatus` ported to a few lines of JavaScript. Apple's system font and SF Symbols are used where
they exist (on an iPhone, `ui-rounded` is SF Pro Rounded); elsewhere Rubik and drawn icons stand in.
