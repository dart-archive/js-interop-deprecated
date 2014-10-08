// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.proxy_creator_test;

import 'package:unittest/unittest.dart';
import 'package:js/proxy_creator.dart';

main() {
  group('Proxy creation', () {

    test('should accept simple name', () {
      expect(createProxySkeleton('MyClass'), '''
abstract class MyClass extends JsInterface {
  factory MyClass() => new MyClassImpl();
  MyClass.created(JsObject o) : super.created(o);
}

@JsProxy(constructor: 'MyClass')
class MyClassImpl extends MyClass {
  factory MyClassImpl() => new JsInterface(MyClassImpl, []);
  MyClassImpl.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}''');
    });

    test('should accept qualified name', () {
      expect(createProxySkeleton('a.b.MyClass'), '''
abstract class MyClass extends JsInterface {
  factory MyClass() => new MyClassImpl();
  MyClass.created(JsObject o) : super.created(o);
}

@JsProxy(constructor: 'a.b.MyClass')
class MyClassImpl extends MyClass {
  factory MyClassImpl() => new JsInterface(MyClassImpl, []);
  MyClassImpl.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}''');
    });

  });
}
