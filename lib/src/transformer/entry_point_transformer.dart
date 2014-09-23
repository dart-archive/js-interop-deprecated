// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.entry_point_transformer;

import 'dart:async';

import 'package:barback/barback.dart' show Asset, AssetId, Transform,
    Transformer, AssetNotFoundException;
import 'package:code_transformers/resolver.dart' show Resolver,
    ResolverTransformer, Resolvers, isPossibleDartEntryId;
import 'package:logging/logging.dart' show Logger;

import 'utils.dart';

final _logger = new Logger('js.transformer.interface_transformer');

class EntryPointTransformer extends Transformer with ResolverTransformer {
  @override
  final Resolvers resolvers;

  EntryPointTransformer(this.resolvers);

  @override
  applyResolver(Transform transform, Resolver resolver) {
    var input = transform.primaryInput;
    var library = resolver.getLibrary(transform.primaryInput.id);
    var entryPoint = library.entryPoint;

    if (entryPoint == null) return null;

    var jsLibrary = resolver.getLibraryByName('js');
    var jsMetadataLibrary = resolver.getLibraryByName('js.metadata');

    if (jsLibrary == null || !library.visibleLibraries.contains(jsLibrary)) {
      return null;
    }

    var transaction = resolver.createTextEditTransaction(library);

    var initializerFutures = resolver.libraries
        .where((lib) =>
            lib != jsLibrary && lib.visibleLibraries.contains(jsLibrary))
        .map((lib) {
          // look for initializer library
          var libAssetId = resolver.getSourceAssetId(lib);
          var dartInitializerAssetId =
              libAssetId.addExtension(DART_INITIALIZER_SUFFIX);
          var jsInitializerAssetId =
              libAssetId.addExtension(JS_INITIALIZER_SUFFIX);
          return [
              transform
                  .getInput(dartInitializerAssetId)
                  .catchError((e) => null,
                      test: (e) => e is AssetNotFoundException),
              transform
                  .getInput(jsInitializerAssetId)
                  .catchError((e) => null,
                      test: (e) => e is AssetNotFoundException),
          ];
        });

    var dartInitializerFutures = initializerFutures.map((l) => l[0]);
    var jsInitializerFutures = initializerFutures.map((l) => l[1]);

    var dartImports = new StringBuffer('\n');
    var dartInitializerCalls = new StringBuffer();

    var dartFuture = Future.wait(dartInitializerFutures)
        .then((initializerAssets) {
          for (Asset asset in initializerAssets.where((a) => a != null)) {
            var id = asset.id;
            var importUri = getImportUri(id, input.id);
            if (importUri == null) continue;
            var prefix = assetIdToPrefix(id);
            dartImports.writeln("import '$importUri' as $prefix;");
            dartInitializerCalls
                .writeln("  $prefix.initializeJavaScriptLibrary();");
          }
        })
        .then((_) {
          var initMethod = 'initializeJavaScript() {\n$dartInitializerCalls}\n';
          var insertImportOffset = getInsertImportOffset(library);
          var initMethodOffset = library.source.contents.data.length;
          transaction.edit(insertImportOffset, insertImportOffset,
              '$dartImports');
          transaction.edit(initMethodOffset, initMethodOffset, initMethod);
          var printer = transaction.commit();
          printer.build(input.id.path);
          transform.addOutput(new Asset.fromString(input.id, printer.text));
        });

    var jsInitializerScript = new StringBuffer('''

window.dart = window.dart || {};

window.dart.Object = function DartObject() {
  throw "not allowed";
};

window.dart.Object._wrapDartObject = function(dartObject) {
  var o = Object.create(window.dart.Object.prototype);
  o.__dart_object__ = dartObject;
  return o;
};

''');

    var jsFuture =
        Future.wait(jsInitializerFutures)
        .then((assets) => Future.wait(assets
            .where((a) => a != null)
            .map((Asset a) => a.readAsString())))
        .then((initializerSources) {
          for (String source in initializerSources) {
            jsInitializerScript.writeln(source);
          }
        }).then((_) {
          var jsInitializerId = input.id.addExtension('_initialize.js');
          var asset = new Asset.fromString(jsInitializerId,
              jsInitializerScript.toString());
          transform.addOutput(asset);
        });
    return Future.wait([dartFuture, jsFuture]);
  }
}
