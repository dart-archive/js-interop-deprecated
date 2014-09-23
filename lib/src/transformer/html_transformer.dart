// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.html_transformer;

import 'package:barback/barback.dart' show Asset, AssetId, Transform,
    Transformer;
import 'package:html5lib/parser.dart' as html;
import 'package:logging/logging.dart' show Logger;
import 'package:path/path.dart' as path;

final _logger = new Logger('js.transformer.html_transformer');

class HtmlTransformer extends Transformer {

  @override
  isPrimary(AssetId id) => path.extension(id.path) == '.html'
      && path.split(id.path).first == 'web';

  /**
   * Transforms .html files that include packages/js/interop.js to include
   * the generated initializer file for the entrypoint instead.
   */
  @override
  apply(Transform transform) {
    var input = transform.primaryInput;
    return input.readAsString().then((source) {
      var doc = html.parse(source, generateSpans: true);
      var interopScriptTag =
          doc.querySelector('script[src="packages/js/interop.js"]');
      var dartScriptTag = doc.querySelector('script[type="application/dart"]');

      if (interopScriptTag != null && dartScriptTag != null) {
        var entryPointPath = dartScriptTag.attributes['src'];
        var initializerPath = entryPointPath + '_initialize.js';

        var span = interopScriptTag.attributeSpans['src'];
        var start = span.start.offset;
        var end = span.end.offset;
        var newSource = source.substring(0, start)
            + 'src="$initializerPath"'
            + source.substring(end);

        transform.addOutput(new Asset.fromString(input.id, newSource));
      }
    });
  }
}
