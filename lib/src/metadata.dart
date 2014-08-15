// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains the annotations used in js.dart separately so they can
 * be imported into the VM.
 */
library js.metadata;

/**
 * A metadata annotation to mark a library, variable, class, function or method
 * declaration for export to JavaScript. All children of the declaration are
 * also exported, unless they are marked with [NoExport].
 */
class Export {
  final String as;
  const Export({this.as});
}

/**
 * A metadata annotation to override an [Export] annotation on a higher-level
 * declaration to not export the target declaration or its children.
 */
class NoExport {
  const NoExport();
}

/**
 * A metadata annotation that marks a class as a proxy implementation for a
 * JsInterface.
 *
 * Classes annotated with @JsProxy() are transformed to add an impementation of
 * all abstract methods defined on superclasses that extend JsInterface.
 */
class JsProxy {
  final String constructor;
  final bool global;
  const JsProxy({this.constructor, this.global: false});
}
