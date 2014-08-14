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
