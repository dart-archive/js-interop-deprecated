// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.interface_generator_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:js/src/transformer/interface_generator.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';
import 'package:barback/barback.dart';

main() {

  group('InterfaceGenerator', () {

    InternalAnalysisContext _context;
    String testLibSource;
    LibraryElement testLib;
    LibraryElement jsLib;

    setUp(() {
      var analyserInfo = initAnalyzer();
      testLib = analyserInfo.testLib;
      jsLib = analyserInfo.jsLib;
      testLibSource = analyserInfo.context.getContents(testLib.source).data;
    });

    // TODO: This test doesn't really do anything. We probably want to compare
    // the output against checked-in known good transformed source and leave the
    // rest of the testing to generated_code_test
    test('should generate implementations for JsInterface subclasses', () {
      var jsInterfaces = new Set.from([
          testLib.getType('ContextImpl'),
          testLib.getType('JsFooImpl'),
          testLib.getType('JsBarImpl')]);
      var jsMetadataLib = jsLib
          .exportedLibraries
          .singleWhere((l) => l.name == 'js.metadata');
      var testSourceFile = new SourceFile(testLibSource);
      var transaction = new TextEditTransaction(testLibSource, testSourceFile);
      var id = new AssetId('test', 'lib/test.dart');
      var generator = new InterfaceGenerator(
          id,
          jsInterfaces, testLib, jsLib,
          jsMetadataLib, transaction);

      var newSource = generator.generate()[id];

      expect(newSource, contains('ContextImpl'));
      expect(newSource, contains('JsFooImpl'));
      expect(newSource, contains('JsBarImpl'));
    });

  });

}
