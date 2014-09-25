// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.entry_point_transformer_test;

import 'package:code_transformers/src/test_harness.dart';
import 'package:js/src/transformer/entry_point_transformer.dart';
import 'package:js/src/transformer/library_transformer.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';
import 'dart:async';

main() {

  group('EntryPointTransformer', () {

    test('runs', () {
      var resolvers = mockResolvers();
      var libraryTransformer = new LibraryTransformer(resolvers);
      var entryPointTransformer = new EntryPointTransformer(resolvers);
      var testHelper = new TestHelper([
          [libraryTransformer],
          [entryPointTransformer]], {
        'test|lib/library.dart': readTestFile('library.dart'),
        'test|web/entry_point.dart': readTestFile('entry_point.dart.test'),
        'js|lib/js.dart': readJsPackageFile('js.dart'),
        'js|lib/src/mirrors.dart': readJsPackageFile('src/mirrors.dart'),
        'js|lib/src/static.dart': readJsPackageFile('src/static.dart'),
        'js|lib/src/js_impl.dart': readJsPackageFile('src/js_impl.dart'),
        'js|lib/src/metadata.dart': readJsPackageFile('src/metadata.dart'),
      }, null);
      testHelper.run();

      return Future.wait([
          testHelper['test|web/entry_point.dart'],
          testHelper['test|web/entry_point.dart_initialize.js'],
      ])
      .then((sources) {
        var dartSource = sources[0];
        var jsSource = sources[1];
        expect(dartSource, contains(
'''
initializeJavaScript() {
  _js__test__web_entry_point_dart__init_js___dart.initializeJavaScriptLibrary();
  _js__test__lib_library_dart__init_js___dart.initializeJavaScriptLibrary();
}
'''));
      });
    });
  });
}
