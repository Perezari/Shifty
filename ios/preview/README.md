# The iPhone app in the browser

`index.html` shows the iPhone app's screens on an iPhone 17 Pro of 402 by 874 points, scaled to fit,
before there is a build: the app's four tabs (Now, with a shift running, on a break, or none, the
period's net pay and the days off left; the shifts; the calendar; the settings, shortened), the Lock
Screen's Live Activity, the Dynamic Island, the widgets, the notifications, Siri's answers and the
period's summary, and the home screen's icon, in light and dark; a long press opens the menus the app
has. What is proposed and not yet built is marked so on the page. It is one page with made-up shifts (the
repository is public), published as a Claude artifact to open on the iPhone; it opens from the file in a
browser too.

A design is tried here first, and built once it is agreed: when a SwiftUI view changes, its counterpart
here changes with it. The clocks and the bar run as the app's do, from `Format.timer` and
`Calc.nowStatus` ported to a few lines of JavaScript. Apple's system font and SF Symbols are used where
they exist (on an iPhone, `ui-rounded` is SF Pro Rounded); elsewhere Rubik and drawn icons stand in.
