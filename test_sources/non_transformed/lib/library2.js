// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

function createDartOnly() {
  return new dart.test.library2.DartOnly();
}

namespace = {};

namespace.Gizmo = function(x) {
  this.x = x;
}

createGizmo = function(x) {
  return new namespace.Gizmo(x);
}

function createJsAndDart(i) {
  return new dart.test.library2.JsAndDart(i);
}
