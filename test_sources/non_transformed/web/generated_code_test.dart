// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.generated_code_test;

import 'dart:html';
import 'dart:js' as js;

import 'package:js/js.dart';
import 'package:js/src/js_list.dart';
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

    var context = new t.Context();

    tearDown(() {
      js.context['a'] = null;
    });

    test('should create a global object', () {
      expect(context, new isInstanceOf<t.Context>());
    });

    test('should return a null value from JS', () {
      expect(context.a, null);
      expect(js.context.callMethod('isNull', [null]), true);
    });

    test('should return a String value from JS', () {
      expect(context.aString, 'hello');
    });

    test('should return a num value from JS', () {
      expect(context.aNum, 123);
    });

    test('should return a bool value from JS', () {
      expect(context.aBool, true);
    });

    test('should return a DateTime value from JS', () {
      expect(context.aDate, new DateTime(2014, 10, 4));
    });

    test('should allowing setting a String', () {
      context.aString = 'hello';
      expect(js.context['aString'], 'hello');
    });

    test('should get a JS object value from JS', () {
      var foo = context.foo;
      expect(foo, new isInstanceOf<t.JsFoo>());
      expect(foo.name, 'made in JS');
    });

    test('should have functioning constructors that delegate to JS', () {
      var foo = new t.JsFoo('a');
      expect(foo, new isInstanceOf<t.JsFoo>());
    });

    test('should produce identical proxies for identical JS objects', () {
      var foo1 = context.foo;
      var foo2 = context.foo;
      expect(foo1, same(foo2));
    });

    test('should get back the same object that was set', () {
      var foo1 = context.foo;
      var foo2 = new t.JsFoo('a');
      expect(foo1, isNot(same(foo2)));

      context.foo = foo2;
      var foo3 = context.foo;
      expect(foo1, isNot(same(foo3)));
      expect(foo2, same(foo3));
    });

    test('should have callable methods', () {
      var foo = new t.JsFoo('a');
      var y = foo.double(7);
      expect(y, 14);
    });

    test('should accept proxies as arguments', () {
      var foo = new t.JsFoo('red');
      var bar = new t.JsBar('blue');
      var name = foo.getName(bar);
      expect(name, 'blue');
    });

    test('should return proxy values', () {
      var foo = new t.JsFoo('red');
      var bar = new t.JsBar('blue');
      foo.setBar(bar);
      expect(foo.bar, bar);
    });

    test('should return Lists', () {
      var library2 = new l2.Library2();
      var l = library2.createList('1', 'b', 'z');
      expect(l, ['1', 'b', 'z']);
    });

    test('should accept Lists', () {
      var library2 = new l2.Library2();
      var s = library2.joinList(['1', 'b', 'z']);
      expect(s, '1, b, z');
    });

    test('should return Lists of proxies', () {
      var library2 = new l2.Library2();
      var a = new t.JsFoo('a');
      var b = new t.JsFoo('b');
      var c = new t.JsFoo('c');

      var l = library2.createList(a, b, c);
      expect(l[0], same(a));
      expect(l[1], same(b));
      expect(l[2], same(c));
    });

    test('should accept Lists of Proxies', () {
      var library2 = new l2.Library2();
      var a = new t.JsFoo('a');
      var b = new t.JsFoo('b');
      var c = new t.JsFoo('c');

      var s = library2.joinList([a, b, c]);
      expect(s, 'a, b, c');
    });

    test('should return Maps', () {
      var library2 = new l2.Library2();
      var m = library2.createMap('a', 1, 'z', 26);
      expect(m, {'a': 1, 'z': 26});
    });

    test('should accept Maps', () {
      var library2 = new l2.Library2();
      var s = library2.joinMap({'a': 1, 'z': 26});
      expect(s, 'a: 1, z: 26');
    });

    test('should return Maps of proxies', () {
      var library2 = new l2.Library2();
      var a = new t.JsFoo('a');
      var b = new t.JsFoo('b');
      var m = library2.createMap('a', a, 'b', b);
      expect(m['a'], same(a));
      expect(m['b'], same(b));
    });

    test('should accept exported object as arguments', () {
      var foo = new t.JsFoo('red');
      var bar = new t.ExportMe.named('blue');
      var name = foo.getName(bar);
      expect(name, 'blue');
    });

    test('should create objects with constructor paths', () {
      var gizmo = new l2.Gizmo('green');
      expect(gizmo.x, 'green');
    });

    test('should return objects with construtor paths', () {
      var library2 = new l2.Library2();
      var gizmo = library2.createGizmo('orange');
      expect(gizmo.x, 'orange');
    });

  });

  group('Exports', () {

    var context = new t.Context();

    test('should be able to construct a Dart object from JS', () {
      var e = context.createExportMe();
      expect(e, new isInstanceOf<t.ExportMe>());
      expect(context.isExportMe(e), isTrue);
    });

    test('should be instances of their JS constructors', () {
      var e = context.createExportMe();
      expect(context.isExportMe(e), isTrue);
    });

    test('should be instances of dart.Object', () {
      var e = context.createExportMe();
      expect(context.isDartObject(e), isTrue);
    });

    test('should be call a no-named constructor with arguments', () {
      var library = new l2.Library2();
      var o = library.createJsAndDart(13);
      expect(o.i, 13);
    });

    test('should be able to call a constructor with optional arguments', () {
      var e = context.createExportMeOptional('green');
      expect(e.name, 'green');
      expect(context.isExportMe(e), isTrue);
    });

    test('should be able to call a constructor with named arguments', () {
      var e = context.createExportMeNamed2('pink');
      expect(e.name, 'pink');
      expect(context.isExportMe(e), isTrue);
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

    test('should be able to call a method with arguments', () {
      var e = context.createExportMe();
      String v = context.callMethod2(e, 'interop');
      expect(v, 'Hello interop!');
    });

    test('should be able to call a method with optional parameters', () {
      var e = context.createExportMe();
      String v = context.callOptionalArgs(e);
      expect(v, '1 2 3');
    });

    test('should be able to call a method with optional parameters', () {
      var e = context.createExportMe();
      String v = context.callOptionalArgs2(e);
      expect(v, '1 2 null');
    });

    test('should be able to call a method with named parameters', () {
      var e = context.createExportMe();
      String v = context.callNamedArgs(e);
      expect(v, '1 2 3');
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

    test('should return lists from methods to JavaScript', () {
      var library2 = new l2.Library2();
      var o = new l2.JsAndDart(0);
      var l = library2.callCreateList(o);
      expect(l, new isInstanceOf<JsList>());
      expect(l, ['x', 'y', 'z']);
    });

    test('should return lists from getters to JavaScript', () {
      var library2 = new l2.Library2();
      var o = new l2.JsAndDart(0);
      var l = library2.callListGetter(o);
      expect(l, new isInstanceOf<JsList>());
      expect(l, [1, 2, 3]);
    });

    test('should return lists from fields to JavaScript', () {
      var library2 = new l2.Library2();
      var o = new l2.JsAndDart(0);
      var l = library2.callListField(o);
      expect(l, new isInstanceOf<JsList>());
      expect(l, [8, 3, 1]);
    });

  });

}
