// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * The js library allows Dart library authors to export their APIs to JavaScript
 * and to define Dart interfaces for JavaScript objects.
 */
library js;

/**
 * A metadata annotation to marks a library, variable, class, funciton or method
 * declaration for export to JavaScript. All children of the declaration are
 * also exported, unless they are marked with [DoNotExport].
 */
class Export {
  final String as;
  const Export({this.as});
}

/**
 * A metadata annotation to overrides an [Export] annotation on a higher-level
 * declaration to not export the target declaration or its children.
 */
class NoExport {
  const NoExport();
}

/**
 * The base class of Dart interfaces for JavaScript objects.
 */
class JsInterface {}

/**
 * A metadata annotation to specify the JavaScript constructor associated with
 * a [JsInterface].
 */
class JsConstructor {
  final String constructor;
  const JsConstructor(this.constructor);
}

/**
 * A metadata annotation to mark a [JsInterface] subclass as proxying the global
 * JavaScript context.
 */
class JsGlobal {
  const JsGlobal();
}
