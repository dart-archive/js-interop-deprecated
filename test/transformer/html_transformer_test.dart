library js.html_transformer_test;

import 'package:unittest/unittest.dart';

import 'package:js/src/transformer/html_transformer.dart';
import 'package:barback/barback.dart';
import 'dart:async';

main() {

  group("$HtmlTransformer", () {
    test('should replace the interop.js script tag', () {
      var transformer = new HtmlTransformer();
      var barback = new Barback(new TestPackageProvider());
      barback.updateTransformers('test', [[transformer]]);
      var id = new AssetId('test', 'web/test.html');
      barback.updateSources([id]);
      return barback.getAssetById(id)
          .then((asset) => asset.readAsString())
          .then((source) {
            expect(source,
                contains('<script src="test.dart_initialize.js"></script>'));
            expect(source,
                isNot(contains(
                    '<script src="packages/js/interop.js"></script>')));
          });
    });
  });

}

class TestPackageProvider implements PackageProvider {
  Iterable<String> get packages => ['test'];

  Future<Asset> getAsset(AssetId id) {
    if (id.package == 'test' && id.path == 'web/test.html') {
      return new Future.value(new Asset.fromString(id,
'''
<html>
  <head>
    <script src="packages/js/interop.js"></script>
  <head>
  <body>
    <script type="application/dart" src="test.dart"></script>
    <script src="packages/browser/dart.js"></script>
  </body>
</html>
'''));
    }
    return null;
  }

}
