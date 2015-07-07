// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * The js library allows Dart library authors to export their APIs to JavaScript
 * and to define Dart interfaces for JavaScript objects.
 */
library js;

/// A metadata annotation that marks an enum as a set of values.
const jsEnum = const _JsEnum();
class _JsEnum {
  const _JsEnum();
}

/// A metadata annotation that allows to customize the name used for method call
/// or attribute access on the javascript side.
///
/// You can use it on libraries, classes, members.
class JsName {
  final String name;
  const JsName([this.name]);
}

/// A metadata annotation used to indicate that the Js object is a anonymous js
/// object. That is it is created with `new Object()`.
const anonymous = const _Anonymous();
class _Anonymous {
  const _Anonymous();
}
