# Standalone svg image rep for macOS

This is a standalone svg image rep for macOS written in Objective-C. The idea behind
it was to have svg image support without the least external dependencies possible.

Note however that it is by no means complete yet.

It is loosely based on older work on PocketSVG by Martin Haywood, Bob Monaghan, John Blanco

## Basic Usage ##

To use in your own projects, import the SVGImageRep class and header into your
project.

```objective-c
#import "SVGImageRep.h"
```
Register the image rep as early in the application execution as possible

```objective-c
[NSImageRep registerImageRepClass: [SVGImageRep class]];
```
After registration svg images can be loaded as you would expect.

```objective-c
NSImage *testImage = [NSImage imageNamed: @"SVG_logo"];
```
For more information and a working sample check out the XCode project.

The SVG_logo.svg sample image is licenced under the [CC 2.5](https://creativecommons.org/licenses/by/2.5/).

## License ##
[BSD (Berkeley Software Distribution) License](http://www.opensource.org/licenses/bsd-license.php).
Copyright (c) 2015-2015, Impending
