// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.js_expando_test;

import 'dart:html';
import 'dart:js' as js;

// these imports instead of js.dart so the transformer doesn't kick in and
// remove mirrors
import 'package:js/src/js_expando.dart';
import 'package:js/src/mirrors.dart';

import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

main() {
  useHtmlEnhancedConfiguration();

  group('JsExpando', () {

    test('should access a JS simple property', () {
      var expando = new JsExpando<String>('foo');
      expect(expando[window], null);
      expando[window] = 'bar';
      expect(expando[window], 'bar');
      // reset global state
      expando[window] = null;
    });

    test('should access a JS simple property', () {
      var expando = new JsExpando<Foo>('foo');
      var foo = new Foo();
      expect(expando[window], null);
      expando[window] = foo;
      expect((js.context['foo'] as JsObject).instanceof(js.context['Foo']),
          isTrue);
      expect(expando[window], same(foo));
    });

  });
}

abstract class Foo extends JsInterface {
  Foo.created(JsObject o) : super.created(o);
  factory Foo() = FooImpl;
}

@JsProxy(constructor: 'Foo')
class FooImpl extends Foo {
  FooImpl.created(JsObject o) : super.created(o);
  factory FooImpl() => new JsInterface(FooImpl, []);
}
