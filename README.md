Dart-JavaScript Interop (paused)
=======================

**Note:** Development on this package has paused. We encourage every developer
to use `dart:js` for Dart-JavaScript interop. Further work on a
higher-level interop with JavaScript will be explored along with
new experimental approaches to compiling to JavaScript.

package:js provides high-level, typed interopability between Dart and
JavaScript. It allows developers to export Dart APIs to JavaScript and define
well-typed interfaces for JavaScript objects.

Status
------

**Paused**

Version 0.4.0 is a complete rewrite of package:js as described in the
package:js 1.0 [design document][design].

[design]: https://docs.google.com/a/google.com/document/d/1X0M7iQ1PraH50353OnjKidgrd0EK6NpLNXVI27jitFY/edit#]

Usage
-----

**Warning: The API is still changing rapidly. Not for the faint of heart**


### Defining Typed JavaScript Proxies

Typed JavaScript Proxies are classes that represent a JavaScript object and have a well-defined Dart API, complete with type annotations, constructors, even optional and named parameters. They are defined in two parts:

  1. An abstract class that defines the interface
  2. A concrete class that implements the interface (automatically, either via mirrors or the `js` transformer)

The abstract class is defined as follows:

  1. It must extend `JsInterface`
  2. It must have a constructor with the signature `C.created(JsObject o)`.
  3. Any abstract methods or accessors on the class are automatically implemented for you to call into JavaScript. Becuase only abstract class members are proxied to JavaScript, fields must be represented as abstract getter/setter pairs.
  4. Ideally, all parameters and returns should have type annotations. The generator adds casts based on the type annotations which help dart2js produce smaller, faster output.
  5. Add a factory constructor if you want to create new instances from Dart. The constructor must redirect to a factory constructor on the implementation class.
  6. Maps and Lists need to be copied to be usable in JavaScript. Add a `@jsify` annotation to any parameter that takes a Map or List. Note that modification from JS won't be visible in Dart, unless you send the copied collection back later.

The concrete implementation class is defined as follows:

  1. It must extend the interface class.
  2. It must have a `created` constructor.
  3. It must have a `@JsProxy` annotation. This tells `package:js` that the class is a proxy, and which JavaScript prototype it should proxy.
  4. It should have a `noSuchMethod` that forwards to the super class to suppress warnings.

#### Example - Proxying JavaScript to Dart

##### JavaScript

```javascript
function Foo(name) {
  this.name = name;
}

Foo.prototype.sayHello = function() {
  return "Hello " + name;
}
```

##### Dart

```dart
import 'package:js/js.dart';

abstract class Foo extends JsInterface {
  Foo.created(JsObject o) : super.created(o);
  
  factory Foo(String name) = FooImpl;
  
  String get name;
  void set name(String n);
  
  String sayHello();
}

@JsProxy(constructor: 'Foo')
class FooImpl extends Foo {
  FooImpl.created(JsObject o) : super.created(o);
  
  factory FooImpl(String name) => new JsInterface(FooImpl, [name]);
  
  noSuchMethod(i) => super.noSuchMethod(i);
}
```

This may seem a bit verbose, and it is, but it's because of a few constraints we have:

  * The proxy methods should be abstract.
  * Abstract members cause warnings on non-abstract classes, which can't be silenced by adding a `noSuchMethod()`, so the proxy class must be abstract.
  * Abstract classes can't be instantiated, so we need a separate implementation class.
  * The abstract methods are implemented via `noSuchMethod()` in `JsInterface`, which doesn't silence the warnings cause be "unimplemented" methods, so we must add a `noSuchMethod()` to the implementation class.
  * The only way to express an "abstract field" is with a getter/setter pair.
  * `JsInterface` needs a reference to the raw `JsObject`, so must have a generative constructor.
  * We want to create new instances with expressions like `new Foo()`, not `new FooImpl()`, so we need a factory constructor on the interface class.

We will try to see what changes we can make in the future to this package or the language to alleviate the boilerplate. The good news is that once the boilerplate for the class is set up, the interesting parts - the methods and fields - are quite simple to write and maintain. We will also look into generators for proxies from various sources like TypeScript, Closure, JSHint annotations, Polymer, etc.

### Exporting Dart APIs to JavaScript

You can export classes, functions, variables, and even whole libraries to JavaScript by using the `@Export` annotation.

#### Example

##### a.dart:

```dart
library a;

import 'package:js/js.dart';

@Export()
class A {
  String name;

  A();

  A.withName(this.name);
}
```

##### JavaScript

```javascript
var a1 = new dart.a.A();
a1 instanceof dart.a.A; // true
a1.name; // null
a1.name = 'red'; // sets the value in Dart

// Named constructors are supported
var a2 = new dart.a.A.withName('blue');
a2 instanceof dart.a.A;
a2.name; // 'blue'
```

All of the types referenced by exported functions and methods must either be "primitives" as defined by dart:js
 (`bool`, `num`, `String`, `DateTime`), JsInterfaces, or other exported classes.
 
As with parameters for JsInterfaces, the return values of exported methods are Dart objects being passed to JavaScript. If these are Maps or Lists, they too must be copied to work in JavaScript, so add `@jsify` to the method, field or getter.

Configuration and Initialization
--------------------------------

### Adding the dependency

Version 0.4.0 is not published to pub.dartlang.org yet, so you must use a Git
dependency to install it.

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  js:
    git:
      url: git://github.com/dart-lang/js-interop.git
```

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

The JavaScript prototypes for exported APIs must be loaded in a page for them to be available to other JavaScript code. This code is loaded by including `packages/js/interop.js` in your HTML. When your application is built that script is replaced by the generated JavaScript. The interop script must be loaded before your main Dart script.

##### main.html

```html
<html>
  <head>
    <script src="packages/js/interop.js"></script>
  </head>
  <body>
    <script type="application/dart" src="main.dart"></script>
  </body>
</html>
```
### Initializing Interop

Your `main()` method must call `initializeJavaScript()` in order to export Dart classes and register proxies. This call should be made as early as possible, ideally first.

##### main.dart

```dart
library main;

import 'package:js/js.dart';

main() {
  initializeJavaScript();
}
```

Contributing and Filing Bugs
----------------------------

Please file bugs and features requests on the Github issue tracker: https://github.com/dart-lang/js-interop/issues

We also love and accept community contributions, from API suggestions to pull requests. Please file an issue before beginning work so we can discuss the design and implementation. We are trying to create issues for all current and future work, so if something there intrigues you (or you need it!) join in on the discussion.

All we require is that you sign the Google Individual Contributor License Agreement https://developers.google.com/open-source/cla/individual?csw=1
