// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.generated_code_test;

import 'dart:html';

import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

// TODO(justinfagnani): this test should work against 3 test libraries:
//  1) Pre-transformed, like test_teansformed.dart
//  2) Transformed, like test.dart run through the transformer
//  3) Non-transformed, like test.dart using mirrors (with the exception of
//     the export tests which rely on generated JS
//import 'test_sources/test.dart' as t;
import 'test_sources/test_transformed.dart' as t;

main() {
  useHtmlEnhancedConfiguration();

  // trigger JS interop initialization
  t.main();

  group('JsInterface', () {

    test('should get a value from the JS context', () {
      var context = new t.Context();
      var foo = context.foo;
      expect(foo, new isInstanceOf<t.JsFoo>());
    });

    test('should have functioning constructors that delegate to JS', () {
      var foo = new t.JsFoo('a');
      expect(foo, new isInstanceOf<t.JsFoo>());
    });

    test('should produce identical proxies for identical JS objects', () {
      var context = new t.Context();
      var foo1 = context.foo;
      var foo2 = context.foo;
      expect(foo1, same(foo2));
    });

    test('should get back the same object that was set', () {
      var context = new t.Context();
      var foo1 = context.foo;
      var foo2 = new t.JsFoo('a');
      expect(foo1, isNot(same(foo2)));

      context.foo = foo2;
      var foo3 = context.foo;
      expect(foo1, isNot(same(foo3)));
      expect(foo2, same(foo3));
    });

  });

  group('Exports', () {

    test('should be able to construct a Dart object from JS', () {
      var context = new t.Context();
      var e = context.createExportMe();
      expect(e, new isInstanceOf<t.ExportMe>());
    });

    test('should be able to pass a Dart object to JS', () {
      var context = new t.Context();
      var e = new t.ExportMe();
      expect(context.isExportMe(e), isTrue);
    });

    test('should have methods callable from JsInterfaces', () {
      var context = new t.Context();
      var e = new t.ExportMe.named('purple');
      String name = context.getName(e);
      expect(name, 'purple');
    });

    test('should survive a round trip', () {
      var context = new t.Context();
      var e = new t.ExportMe.named('purple');
      var e2 = context.roundTrip(e);
      expect(e, same(e2));
    });

  });

}
