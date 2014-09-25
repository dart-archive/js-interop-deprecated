// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.library_transformer_test;

import 'package:code_transformers/src/test_harness.dart';
import 'package:js/src/transformer/library_transformer.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {

  group('LibraryTransformer', () {

    test('runs', () {
      var resolvers = mockResolvers();
      var transformer = new LibraryTransformer(resolvers);
      var testHelper = new TestHelper([[transformer]], {
        'test|lib/library.dart': readTestFile('library.dart'),
        'js|lib/js.dart': readJsPackageFile('js.dart'),
        'js|lib/src/mirrors.dart': readJsPackageFile('src/mirrors.dart'),
        'js|lib/src/static.dart': readJsPackageFile('src/static.dart'),
        'js|lib/src/js_impl.dart': readJsPackageFile('src/js_impl.dart'),
        'js|lib/src/metadata.dart': readJsPackageFile('src/metadata.dart'),
      }, null);
      testHelper.run();
      return testHelper['test|lib/library.dart'].then((testSource) {
         expect(testSource, contains(
             "String get aString => __package_js_impl__.""toDart("
             "__package_js_impl__.toJs(this)['aString']) as String;"));
      });
    });
  });
}
