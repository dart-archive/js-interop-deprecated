// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.scanning_visitor_test;

import 'dart:io';

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:code_transformers/resolver.dart' show MockDartSdk;
import 'package:js/src/transformer/scanning_visitor.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {

  group('ScanningVisitor', () {
    InternalAnalysisContext _context;
    LibraryElement testLib;
    LibraryElement jsLib;

    setUp(() {
      _context = AnalysisEngine.instance.createAnalysisContext();
      var sdk = new MockDartSdk(mockSdkSources, reportMissing: false);
      var options = new AnalysisOptionsImpl();
      _context.analysisOptions = options;
      sdk.context.analysisOptions = options;
      var testResolver = new TestUriResolver(testSources);
      _context.sourceFactory = new SourceFactory([sdk.resolver, testResolver]);
      var testSource = testResolver
          .resolveAbsolute(Uri.parse('package:test/test.dart'));
      _context.parseCompilationUnit(testSource);
      var jsSource = testResolver
          .resolveAbsolute(Uri.parse('package:js/js.dart'));

      testLib = _context.computeLibraryElement(testSource);
      jsLib = _context.getLibraryElement(jsSource);
    });

    test('finds JsInterfaces', () {
      var visitor = new ScanningVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.jsInterfaces, new Set.from([
          testLib.getType('Context'),
          testLib.getType('JsFoo'),
          testLib.getType('JsBar')]));
    });

    test('finds @Exported classes', () {
      var visitor = new ScanningVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements, contains(testLib.getType('ExportMe')));
    });

    test('does not export non-exported classes', () {
      var visitor = new ScanningVisitor(jsLib, testLib)
          ..visitLibraryElement(testLib);
      expect(visitor.exportedElements,
          isNot(contains(testLib.getType('Context'))));
      expect(visitor.exportedElements,
          isNot(contains(testLib.getType('DoNotExport'))));
    });
  });
}

final Map testSources = {
  'package:js/js.dart':
      new File('../../lib/js.dart').readAsStringSync(),
  'package:test/test.dart':
    new File('./test_sources/test.dart').readAsStringSync(),
};
