// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('js_tests');

#import('dart:html');
#import('../packages/unittest/unittest.dart');
#import('../packages/unittest/html_config.dart');

#import('../lib/js.dart', prefix: 'js');

final TEST_JS = '''
  var x = 42;

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
    });
  });

  test('global scope', () {
    var x;
    var y;
    js.scoped(() {
      x = new js.Proxy(js.context.Foo, 42);
      y = new js.Proxy(js.context.Foo, 38);
      js.retain(y);
    });
    js.scoped(() {
      expect(y.a, equals(38));
      js.release(y);
      // TODO(vsm): Invalid proxies are not throwing a catchable
      // error.  Fix and test that x and y are invalid here.
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
}
