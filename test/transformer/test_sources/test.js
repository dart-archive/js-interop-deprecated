// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

var foo = new JsThing('made in JS');

function JsThing(name) {
  this.name = name;
  this.bar = null;
}

/*
JsThing.prototype.getBar = function(bar) {
  return bar;
}
*/

function JsThing2() {
  this.y = 42;
}

function createExportMe() {
  var e = new dart.js.transformer_test.ExportMe();
  return e;
}

function isExportMe(e) {
  return e instanceof dart.js.transformer_test.ExportMe;
}

function getName(hasName) {
  return hasName.name;
}

function roundTrip(e) {
  return e;
}

// hand-generated export code derived from test.dart

window.dart = window.dart || {};

window.dart.Object = function DartObject() {
  throw "not allowed";
};

window.dart.Object._wrapDartObject = function(dartObject) {
  var o = Object.create(window.dart.Object.prototype);
  o.__dart_object__ = dartObject;
  return o;
};

_export_dart_js(dart);

function _export_dart_js(parent) {
  var lib = parent.js = {};
  _export_dart_js_transformer__test(lib);
}

function _export_dart_js_transformer__test(parent) {
  var lib = parent.transformer_test = {};
  _export_js_transformer__test_ExportMe(lib);
}

function _export_js_transformer__test_ExportMe(parent) {
  var constructor = parent.ExportMe = function ExportMeJs() {
    this.__dart_object__ = constructor._new();
  };
  constructor.prototype = Object.create(dart.Object.prototype);
  constructor.prototype.constructor = constructor;
  constructor._wrapDartObject = function(dartObject) {
    var o = Object.create(constructor.prototype);
    o.__dart_object__ = dartObject;
    return o;
  };

  // named constructor
  constructor.named = function ExportMeJs() {
    this.__dart_object__ = constructor._new_named();
  };
  constructor.named.prototype = constructor.prototype;
}
