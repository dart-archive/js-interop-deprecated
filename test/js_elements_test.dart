// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.generated_code_test;

import 'package:unittest/unittest.dart';
import 'package:js/src/js_elements.dart';

main() {
  group('JsElements', () {

    test('should add a new library', () {
      var elements = new JsElements();
      var a = elements.getLibrary('a');
      expect(a.name, 'a');
      expect(elements.exportedLibraries.length, 1);
    });

    test('should add a new nested library with an existing parent', () {
      var elements = new JsElements();
      var a = elements.getLibrary('a');
      var b = elements.getLibrary('a.b');
      expect(b.parent, same(a));
      expect(elements.exportedLibraries.length, 1);
    });

    test('should add a new nested library without an existing parent', () {
      var elements = new JsElements();
      var b = elements.getLibrary('a.b');
      expect(b.parent, isNot(isNull));
      var a = elements.getLibrary('a');
      expect(b.parent, same(a));
      expect(elements.exportedLibraries.length, 1);
    });

    test('should add a new nested library with an existing name', () {
      var elements = new JsElements();
      var b1 = elements.getLibrary('a.b');
      var b2 = elements.getLibrary('c.d.b');
      expect(b1, isNot(same(b2)));
      expect(b1.parent, isNot(same(b2.parent)));
      expect(elements.exportedLibraries.length, 2);
    });

  });
}
