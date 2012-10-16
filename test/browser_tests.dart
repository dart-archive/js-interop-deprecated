// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js_tests;

import 'dart:html';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

import 'package:js/js.dart' as js;

final TEST_JS = '''
  var x = 42;
  var myArray = ["value1"];

  function razzle() {
    return x;
  }

  function Foo(a) {
    this.a = a;
  }

  Foo.prototype.bar = function() {
    return this.a;
  }

  function isArray(a) {
    return a instanceof Array;
  }

  function checkMap(m, key, value) {
    if (m.hasOwnProperty(key))
      return m[key] == value;
    else
      return false;
  }

  function invokeCallback() {
    return callback();
  }

  function returnElement(element) {
    return element;
  }

  function getElementAttribute(element, attr) {
    return element.getAttribute(attr);
  }

  function addClassAttributes(list) {
    var result = "";
    for (var i=0; i<list.length; i++) {
      result += list[i].getAttribute("class");
    }
    return result;
  }

  function getNewDivElement() {
    return document.createElement("div");
  }

  function testJsMap(callback) {
    var result = callback();
    return result['value'];
  }
''';

injectSource(code) {
  final script = new ScriptElement();
  script.type = 'text/javascript';
  script.innerHTML = code;
  document.body.nodes.add(script);
}

main() {
  useHtmlConfiguration();

  injectSource(TEST_JS);

  test('require scope', () {
      expect(() => js.context, throws);
  });

  test('read global field', () {
    js.scoped(() {
      expect(js.context.x, equals(42));
      expect(js.context['x'], equals(42));
      expect(() => js.context.y, throwsA(isNoSuchMethodError));
    });
  });

  test('write global field', () {
    js.scoped(() {
      js.context.y = 42;
      expect(js.context.y, equals(42));
      expect(js.context['y'], equals(42));
    });
  });

  test('call JS function', () {
    js.scoped(() {
      expect(js.context.razzle(), equals(42));
      expect(() => js.context.dazzle(), throwsA(isNoSuchMethodError));
    });
  });

  test('allocate JS object', () {
    js.scoped(() {
      var foo = new js.Proxy(js.context.Foo, 42);
      expect(foo.a, equals(42));
      expect(foo.bar(), equals(42));
      expect(() => foo.baz(), throwsA(isNoSuchMethodError));
    });
  });

  test('allocate JS array and map', () {
    js.scoped(() {
      var array = js.array([1, 2, 3]);
      var map = js.map({'a': 1, 'b': 2});
      expect(js.context.isArray(array));
      expect(array.length, equals(3));
      expect(!js.context.isArray(map));
      expect(js.context.checkMap(map, 'a', 1));
      expect(!js.context.checkMap(map, 'c', 3));
    });
  });

  test('invoke Dart callback from JS', () {
    js.scoped(() {
      expect(() => js.context.invokeCallback(), throws);

      js.context.callback = new js.Callback.once(() => 42);
      expect(js.context.invokeCallback(), equals(42));
      expect(() => js.context.invokeCallback(), throws);
    });
  });

  test('global scope', () {
    var x;
    var y;
    js.scoped(() {
      x = new js.Proxy(js.context.Foo, 42);
      y = new js.Proxy(js.context.Foo, 38);
      expect(x.a, equals(42));
      expect(y.a, equals(38));
      js.retain(y);
    });
    js.scoped(() {
      expect(() => x.a, throws);
      expect(y.a, equals(38));
      js.release(y);
      expect(() => y.a, throws);
    });
  });

  test('pass unattached Dom Element', () {
    js.scoped(() {
      final div = new DivElement();
      div.classes.add('a');
      expect(js.context.getElementAttribute(div, 'class'), equals('a'));
    });
  });

  test('pass unattached Dom Element two times on same call', () {
    js.scoped(() {
      final div = new DivElement();
      div.classes.add('a');
      expect(js.context.addClassAttributes(js.array([div, div])), equals('aa'));
    });
  });

  test('pass Dom Element attached to an unattached element', () {
    js.scoped(() {
      final div = new DivElement();
      div.classes.add('a');
      final container = new DivElement();
      container.elements.add(div);
      expect(js.context.getElementAttribute(div, 'class'), equals('a'));
    });
  });

  test('pass 2 Dom Elements attached to an unattached element', () {
    js.scoped(() {
      final div1 = new DivElement();
      div1.classes.add('a');
      final div2 = new DivElement();
      div2.classes.add('b');
      final container = new DivElement();
      container.elements.add(div1);
      container.elements.add(div2);
      final f = js.context.addClassAttributes;
      expect(f(js.array([div1, div2])), equals('ab'));
    });
  });

  test('pass multiple Dom Elements unattached to document', () {
    js.scoped(() {
      // A is alone
      // 1 and 3 are brother
      // 2 is child of 3
      final divA = new DivElement()..classes.add('A');
      final div1 = new DivElement()..classes.add('1');
      final div2 = new DivElement()..classes.add('2');
      final div3 = new DivElement()..classes.add('3')..elements.add(div2);
      final container = new DivElement()..elements.addAll([div1, div3]);
      final f = js.context.addClassAttributes;
      expect(f(js.array([divA, div1, div2, div3])), equals('A123'));
      expect(f(js.array([divA, div1, div3, div2])), equals('A132'));
      expect(f(js.array([divA, div1, div1, div3, divA, div2, div3])),
          equals('A113A23'));
      expect(!document.documentElement.contains(divA));
      expect(!document.documentElement.contains(div1));
      expect(!document.documentElement.contains(div2));
      expect(!document.documentElement.contains(div3));
      expect(!document.documentElement.contains(container));
    });
  });

  test('pass one Dom Elements unattached and another attached', () {
    js.scoped(() {
      final div1 = new DivElement()..classes.add('1');
      final div2 = new DivElement()..classes.add('2');
      document.documentElement.elements.add(div2);
      final f = js.context.addClassAttributes;
      expect(f(js.array([div1, div2])), equals('12'));
      expect(!document.documentElement.contains(div1));
      expect(document.documentElement.contains(div2));
    });
  });

  test('pass documentElement', () {
    js.scoped(() {
      expect(js.context.returnElement(document.documentElement),
          equals(document.documentElement));
    });
  });

  test('retrieve unattached Dom Element', () {
    js.scoped(() {
      var result = js.context.getNewDivElement();
      expect(result is DivElement);
      expect(!document.documentElement.contains(result));
    });
  });

  test('return a JS proxy to JavaScript', () {
    js.scoped(() {
      var result = js.context.testJsMap(
          new js.Callback.once(() => js.map({ 'value': 42 })));
      expect(result, 42);
    });
  });

  test('dispose a callback', () {
    js.scoped(() {
      var x = 0;
      final callback = new js.Callback.many(() => x++);
      js.context.callback = callback;
      expect(js.context.invokeCallback(), equals(0));
      expect(js.context.invokeCallback(), equals(1));
      callback.dispose();
      expect(() => js.context.invokeCallback(), throws);
    });
  });

  test('test proxy equality', () {
    js.scoped(() {
      var foo1 = new js.Proxy(js.context.Foo, 1);
      var foo2 = new js.Proxy(js.context.Foo, 2);
      js.context.foo = foo1;
      js.context.foo = foo2;
      expect(foo1 != js.context.foo);
      expect(foo2 == js.context.foo);
    });
  });

  test('test instanceof', () {
    js.scoped(() {
      var foo = new js.Proxy(js.context.Foo, 1);
      expect(js.instanceof(foo, js.context.Foo), equals(true));
      expect(js.instanceof(foo, js.context.Object), equals(true));
      expect(js.instanceof(foo, js.context.String), equals(false));
    });
  });

  test('test index get and set', () {
    js.scoped(() {
      final myArray = js.context.myArray;
      expect(myArray.length, equals(1));
      expect(myArray[0], equals("value1"));
      myArray[0] = "value2";
      expect(myArray.length, equals(1));
      expect(myArray[0], equals("value2"));

      final foo = new js.Proxy(js.context.Foo, 1);
      foo["getAge"] = new js.Callback.once(() => 10);
      expect(foo.getAge(), equals(10));
    });
  });
}
