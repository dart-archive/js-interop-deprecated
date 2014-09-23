// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

var foo = new JsThing('made in JS');
var aString = 'hello';
var aNum = 123;
var aBool = true;
var a = null;

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
  var e = new dart.test.library.ExportMe();
  return e;
}

function isExportMe(e) {
  return e instanceof dart.test.library.ExportMe;
}

function getName(hasName) {
  return hasName.name;
}

function roundTrip(e) {
  return e;
}

function isNull(value) {
  return value === null;
}
