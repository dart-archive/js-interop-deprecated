// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.scanning_visitor_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:js/src/transformer/scanning_visitor.dart';
import 'package:js/src/js_elements.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {

  group('ScanningVisitor', () {
    LibraryElement testLib;
    LibraryElement jsLib;
    LibraryElement jsMetadataLib;

    setUp(() {
      var analyserInfo = initAnalyzer();
      testLib = analyserInfo.testLib;
      jsLib = analyserInfo.jsLib;
      jsMetadataLib = jsLib
          .exportedLibraries
          .singleWhere((l) => l.name == 'js.metadata');

    });

    test('should find JsProxy annotated classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.jsElements.proxies, [
          new Proxy('ContextImpl', true, null),
          new Proxy('JsFooImpl', null, 'JsThing'),
          new Proxy('JsBarImpl', null, 'JsThing2')]);
    });

    test('should find @Exported classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      var exports = visitor.jsElements;
      expect(exports.exportedLibraries.keys, ['test']);
      expect(exports.exportedLibraries['test'].children.keys,
          ['library']);
      expect(exports.exportedLibraries['test'].children['library'],
          new isInstanceOf<ExportedLibrary>());
      expect(exports.exportedLibraries['test']
          .children['library']
          .declarations['ExportMe'],
          new isInstanceOf<ExportedClass>());
    });

    test('should include public members of @Exported classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      var exports = visitor.jsElements;
      ExportedClass exportMe = exports.exportedLibraries['test']
          .children['library']
          .declarations['ExportMe'];
      expect(exportMe.children.keys, unorderedEquals(
          ['staticField', 'staticMethod', '', 'named', 'name', 'method',
           'getter', 'optionalArgs', 'namedArgs']));
    });

    test('should not export non-exported classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      var exports = visitor.jsElements;
      expect(exports.exportedLibraries['test'].children['library'],
          isNot(contains('Context')));
      expect(exports.exportedLibraries['test'].children['library'],
          isNot(contains('DoNotExport')));
    });
  });
}
