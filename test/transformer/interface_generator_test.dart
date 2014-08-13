// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.interface_generator_test;

import 'dart:io';

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:code_transformers/resolver.dart' show MockDartSdk;
import 'package:js/src/transformer/scanning_visitor.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';
import 'package:js/src/transformer/interface_generator.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

main() {

  group('InterfaceGenerator', () {

    InternalAnalysisContext _context;
    String testLibSource;
    LibraryElement testLib;
    LibraryElement jsLib;

    setUp(() {
      _context = AnalysisEngine.instance.createAnalysisContext();
      var sdk = new MockDartSdk(mockSdkSources, reportMissing: false);
      var options = new AnalysisOptionsImpl();
      _context.analysisOptions = options;
      sdk.context.analysisOptions = options;

      testLibSource = new File('test_sources/test.dart').readAsStringSync();
      var testSources = {
        'package:js/js.dart':
            new File('../../lib/js.dart').readAsStringSync(),
        'package:test/test.dart': testLibSource,
      };
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

    test('should generate implementations for JsInterface subclasses', () {
      var jsInterfaces = new Set.from([
          testLib.getType('Context'),
          testLib.getType('JsFoo'),
          testLib.getType('JsBar')]);
      var testSourceFile = new SourceFile(testLibSource);
      var transaction = new TextEditTransaction(testLibSource, testSourceFile);
      var generator =
          new InterfaceGenerator(jsInterfaces, testLib, jsLib, transaction);
      var result = generator.generate();

      // TODO: better generated code tests!
      // We can check each generated member for existence, but for behavior
      // it'll be better to instantiate the result and run tests against mock
      // JsObjects

      expect(result, contains('ContextImpl'));
      expect(result, contains('JsFooImpl'));
      expect(result, contains('JsBarImpl'));
    });

  });

}
