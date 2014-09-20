window.dart = window.dart || {};

window.dart.Object = function DartObject() {
  throw "not allowed";
};

window.dart.Object._wrapDartObject = function(dartObject) {
  var o = Object.create(window.dart.Object.prototype);
  o.__dart_object__ = dartObject;
  return o;
};
