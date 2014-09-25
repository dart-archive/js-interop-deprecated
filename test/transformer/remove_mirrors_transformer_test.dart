// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.remove_mirrors_transformer_test;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:js/src/transformer/remove_mirrors_transformer.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {

  group("$RemoveMirrorsTransformer", () {
    test('should replace the mirrors.dart import', () {
      var transformer = new RemoveMirrorsTransformer();
      var barback = new Barback(new TestPackageProvider());
      barback.updateTransformers('js', [[transformer]]);
      var id = new AssetId('js', 'lib/js.dart');
      barback.updateSources([id]);
      return barback.getAssetById(id)
          .then((asset) => asset.readAsString())
          .then((source) {
            expect(source,
                contains("export 'package:js/src/static.dart';"));
            expect(source,
                isNot(contains(
                    "export 'package:js/src/mirrors.dart';")));
          });
    });
  });

}

class TestPackageProvider implements PackageProvider {
  Iterable<String> get packages => ['js'];

  Future<Asset> getAsset(AssetId id) {
    if (id.package == 'js' && id.path == 'lib/js.dart') {
      return new Future.value(
          new Asset.fromString(id, readJsPackageFile('js.dart')));
    }
    return null;
  }

}
