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
}
