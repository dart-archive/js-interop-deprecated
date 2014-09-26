// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.generated_code_test;

import 'dart:html';
import 'dart:js' as js;

import 'package:js/js.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

// TODO(justinfagnani): this test should work against 3 test libraries:
//  1) Pre-transformed: test_teansformed.dart
//  2) Transformed: test.dart run through the transformer
//  3) Non-transformed: test.dart using mirrors (with the exception of
//     the export tests which rely on generated JS
//     The 'JsInterface' group currently passes, but not the 'Exports' group.
//import 'test_sources/test.dart' as t;
import 'package:test/library.dart' as t;
import 'package:test/library2.dart' as l2;

main() {
  useHtmlEnhancedConfiguration();

  // trigger JS interop initialization
  initializeJavaScript();

  // Note: Since these tests interact with the JavaScript environment, it's
  // important to be careful of the state that the tests leave the environment
  // in so that the tests are independent
  group('JsInterface', () {

    tearDown(() {
      js.context['a'] = null;
    });

    test('should create a global object', () {
      var context = new t.Context();
      expect(context, new isInstanceOf<t.Context>());
    });

    test('should return a null value from JS', () {
      var context = new t.Context();
      expect(context.a, null);
      expect(js.context.callMethod('isNull', [null]), true);
    });

    test('should return a String value from JS', () {
      var context = new t.Context();
      expect(context.aString, 'hello');
    });

    test('should return a num value from JS', () {
      var context = new t.Context();
      expect(context.aNum, 123);
    });

    test('should return a bool value from JS', () {
      var context = new t.Context();
      expect(context.aBool, true);
    });

    test('should return a DateTime value from JS', () {
      var context = new t.Context();
      expect(context.aDate, new DateTime(2014, 10, 4));
    });

    test('should allowing setting a String', () {
      var context = new t.Context();
      context.aString = 'hello';
      expect(js.context['aString'], 'hello');
    });

    test('should get a JS object value from JS', () {
      var context = new t.Context();
      var foo = context.foo;
      expect(foo, new isInstanceOf<t.JsFoo>());
      expect(foo.name, 'made in JS');
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

    var context = new t.Context();

    test('should be able to construct a Dart object from JS', () {
      var e = context.createExportMe();
      expect(e, new isInstanceOf<t.ExportMe>());
    });

    test('should be able to pass a Dart object to JS', () {
      var e = new t.ExportMe();
      expect(context.isExportMe(e), isTrue);
    });

    test('should have working named constructors', () {
      var e = context.createExportMeNamed('purple');
      expect(e, new isInstanceOf<t.ExportMe>());
    });

    test('should be able to get a field', () {
      var e = new t.ExportMe.named('purple');
      String name = context.getName(e);
      expect(name, 'purple');
    });

    test('should be able to set a field', () {
      var e = new t.ExportMe();
      context.setName(e, 'red');
      expect(e.name, 'red');
    });

    test('should be able to call a method', () {
      var e = context.createExportMe();
      int v = context.callMethod(e);
      expect(v, 42);
    });

    test('should be able to get a getter', () {
      var e = new t.ExportMe();
      bool v = context.getGetter(e);
      expect(v, true);
    });

    test('should be able to set a setter', () {
      var e = new t.ExportMe();
      context.setSetter(e, 'red');
      expect(e.name, 'red');
    });

    test('should survive a round trip', () {
      var e = new t.ExportMe.named('purple');
      var e2 = context.roundTrip(e);
      expect(e, same(e2));
    });

    test('should be able create more than one global proxy type', () {
      var library2 = new l2.Library2();
      expect(library2, isNot(context));
    });

    test('should not export non-exported classes', () {
      expect(js.context['dart']['test']['library2'], isNotNull);
      expect(js.context['dart']['test']['library2']['DartOnly'], isNull);
      expect(js.context['dart']['test']['library2']['Library2'], isNull);
      expect(js.context['dart']['test']['library2']['Library2Impl'], isNull);
    });

  });

}
