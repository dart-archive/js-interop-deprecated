// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.remove_mirrors_transformer;

import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer;
import 'package:logging/logging.dart' show Logger;

final _logger = new Logger('js.transformer.remove_mirrors_transformer');

class RemoveMirrorsTransformer extends Transformer {

  RemoveMirrorsTransformer();

  RemoveMirrorsTransformer.asPlugin(BarbackSettings settings);

  @override
  isPrimary(AssetId id) => id.package == 'js' && id.path == 'lib/js.dart';

  @override
  apply(Transform transform) {
    var input = transform.primaryInput;
    return input.readAsString().then((source) {
      var newSource = source.replaceAll(
          "export 'package:js/src/mirrors.dart';",
          "export 'package:js/src/static.dart';");
      transform.addOutput(new Asset.fromString(input.id, newSource));
    });
  }
}
