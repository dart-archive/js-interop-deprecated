// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.scanning_visitor_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:js/src/transformer/scanning_visitor.dart';
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
      expect(visitor.jsProxies, new Set.from([
          testLib.getType('ContextImpl'),
          testLib.getType('JsFooImpl'),
          testLib.getType('JsBarImpl')]));
    });

    test('should find @Exported classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements, contains(testLib.getType('ExportMe')));
    });

    test('should not export non-exported classes', () {
      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements,
          isNot(contains(testLib.getType('Context'))));
      expect(visitor.exportedElements,
          isNot(contains(testLib.getType('DoNotExport'))));
    });
  });
}
