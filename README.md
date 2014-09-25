Dart-JavaScript Interop
=======================

package:js provides high-level, typed interopability between Dart and
JavaScript. It allows developers to export Dart APIs to JavaScript and define
well-typed interfaces for JavaScript objects.

Status
------

Version 0.4.0 is a complete rewrite of package:js as described in the
package:js 1.0 [design document][design].

The development plan is to build out the first release of this new version of
package:js and publish as 0.4.0, then rapidly release new versions as
development progresses using semantic versioning, but shifting the meaning of
the version number one to the right. This means that 0.5.0 will be a breaking
change in some way from 0.4.0. Version 1.0 will signify that the features and
API have stabilized.

[design]: https://docs.google.com/a/google.com/document/d/1X0M7iQ1PraH50353OnjKidgrd0EK6NpLNXVI27jitFY/edit#]

Usage
-----

### Defining Typed JavaScript Proxies

Typed JavaScript Proxies are classes that have represent a JavaScript object and have a well-defined API. They are defined in two parts:

  1. An abstract class that defines the interface
  2. A concrete class that implements the interface (automaticlly via mirrors or the transformer)

The abstract class must extend `JsInterface` and must have a constructor with the signature `created(JsObject o)`. Any abstract methods or accessors on the class are automatically implemented for you to call into JavaScript.

The concrete implementation class must extend the interface class, and must also have a `created` constructor. It must also have a `@JsProxy` annotation which tells `package:js` that the class is a proxy, and which JavaScript prototype it should proxy. You also will want to add a `noSuchMethod` that forwards to the super class to suppress warnings.

#### Example

    import 'package:js/js.dart';

    abstract class Foo extends JsInterface {
      Foo.created(JsObject o) : super.created(o);

      String getName();
    }

    @JsProxy(constructor: 'Foo')
    class FooImpl extends Foo {
      Foo.created(JsObject o) : super.created(o);
      noSuchMethod(i) => super.noSuchMethod(i);
    }

### Exporting Dart APIs to JavaScript

You can export classes, functions, variables, and even whole libraries to JavaScript by using the `@Export` annotation.

#### Example

##### a.dart:

    library a;

    import 'package:js/js.dart';

    @Export()
    class A {
      String name;

      A();

      A.withName(this.name);
    }

##### JavaScript

    var a1 = new dart.a.A();
    a1 instanceof dart.a.A; // true
    a1.name; // null
    a1.name = 'red'; // sets the value in Dart

    // Named constructors are supported
    var a2 = new dart.a.A.withName('blue');
    a2 instanceof dart.a.A;
    a2.name; // 'blue'

All of the types referenced by exported functions and methods must either be "primitives" as defined by dart:js
 (`bool`, `num`, `String`, `DateTime`), JsInterfaces, or other exported classes.

Installing
----------

**Warning: The API is still changing rapidly. Not for the faint of heart**

### Adding the dependency

Version 0.4.0 is not published to pub.dartlang.org yet, so you must use a Git
dependency to install it.

Add the following to your `pubspec.yaml`:

    dependencies:
      js:
        git:
          url: git://github.com/dart-lang/js-interop.git
          ref: 0.4.0

### Configuring the transformers

`package:js` requires two transformers to be installed, a transformer that works on packages that directly use `package:js` to generate implementations of JavaScript proxy classes, and another transformer that works on entry-points that generates the necessary setup code.

If your packages uses `package:js` to export APIs or define JavaScript proxies, add this to your `pubspec.yaml`:

    transformers:
    - js

If your packages defines an entry-point in `web/`, add this to your `pubspec.yaml`:

    transformers:
    - js/intializer

If your package both defines proxies or exports, and has an HTML entry-point in `web/`, then add both transformers:

    transformers:
    - js
    - js/intializer

### Loading the generated JavaScript

The JavaScript prototypes for exported APIs must be loaded in a page for them to be available to other JavaScript code. This code is loaded by including `packages/js/interop.js` in your HTML. When your application is built that script is replaced by the generated JavaScript.

    <html>
      <head>
        <script src="packages/js/interop.js"></script>
      </head>
    </html>
