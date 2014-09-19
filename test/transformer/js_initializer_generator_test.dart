// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.initializer_generator_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';
import 'package:barback/barback.dart';
import 'package:js/src/transformer/scanning_visitor.dart';
import 'package:js/src/transformer/js_initializer_generator.dart';

main() {

  group('InitializerGenerator', () {

    InternalAnalysisContext _context;
    String testLibSource;
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
      testLibSource = analyserInfo.context.getContents(testLib.source).data;
    });

    // TODO: This test doesn't really do anything. We probably want to compare
    // the output against checked-in known good transformed source and leave the
    // rest of the testing to generated_code_test
    test('should generate implementations for JsInterface subclasses', () {
      var jsProxies = new Set.from([
          testLib.getType('ContextImpl'),
          testLib.getType('JsFooImpl'),
          testLib.getType('JsBarImpl')]);

      var visitor = new ScanningVisitor(jsLib, jsMetadataLib, testLib)
          ..visitLibraryElement(testLib);

      var testSourceFile = new SourceFile(testLibSource);
      var transaction = new TextEditTransaction(testLibSource, testSourceFile);
      var id = new AssetId('test', 'lib/test.dart');
      var generator = new JsInitializerGenerator(
          'js.transformer_test',
          'lib/test.dart',
          visitor.jsElements);

      var source = generator.generate();

      expect(source, contains('initializeJavaScriptLibrary()'));
      expect(source, contains('_export_test_library_ExportMe'));
    });

  });

}
