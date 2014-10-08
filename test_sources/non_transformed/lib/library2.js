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

function createList(a, b, c) {
  return [a, b, c];
}

function joinList(list) {
  if (!Array.isArray(list)) {
    throw "Not an Array";
  }
  return list.join(', ');
}

function joinMap(map) {
  var pairs = [];
  var names = Object.keys(map);
  for (var i in names) {
    var name = names[i];
    var value = map[name]
    pairs.push(name + ': ' + value);
  }
  return pairs.join(', ');
}

function createMap(k1, v1, k2, v2) {
  var m = {};
  m[k1] = v1;
  m[k2] = v2;
  return m;
}


function callCreateList(o) {
  var list = o.createList('x', 'y', 'z');
  if (!Array.isArray(list)) {
    throw "Not an Array";
  }
  return list;
}

function callListGetter(o) {
  var list = o.listGetter;
  if (!Array.isArray(list)) {
    throw "Not an Array";
  }
  return list;
}

function callListField(o) {
  var list = o.listField;
  if (!Array.isArray(list)) {
    throw "Not an Array";
  }
  return list;
}
