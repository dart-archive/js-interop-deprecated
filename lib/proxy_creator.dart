// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.proxy_creator;

String createProxySkeleton(String name) {
  final className = name.substring(name.lastIndexOf('.') + 1);
  final implClassName = className + 'Impl';
  return '''
abstract class $className extends JsInterface {
  factory $className() => new $implClassName();
  $className.created(JsObject o) : super.created(o);
}

@JsProxy(constructor: '$name')
class $implClassName extends $className {
  factory $implClassName() => new JsInterface($implClassName, []);
  $implClassName.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}''';
}
