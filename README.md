Dart JavaScript Interop
===================

The js.dart library allows Dart code running in the browser to
manipulate JavaScript running in the same page.  It is intended to
allow Dart code to easily interact with third-party JavaScript libraries.

This library is under construction. More coming soon!

Running Tests
-------------

First, use the [Pub Package Manager][pub] to install dependencies:

    pub install

To run browser tests on [Dartium], simply open **test/browser_tests.html**
in Dartium.

To run browser tests using JavaScript in any modern browser, first use the
following command to compile to JavaScript:

    dart2js -otest/browser_tests.dart.js test/browser_tests.dart

and then open **test/browser_tests.html** in any browser.

[d]: http://www.dartlang.org
[mb]: http://www.dartlang.org/support/faq.html#what-browsers-supported
[pub]: http://www.dartlang.org/docs/pub-package-manager/
[Dartium]: http://www.dartlang.org/dartium/index.html
