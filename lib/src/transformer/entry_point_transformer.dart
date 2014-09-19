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
import 'package:path/path.dart' as path;

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
          var initializerAssetId = libAssetId.addExtension(INITIALIZER_SUFFIX);
          return transform
              .getInput(initializerAssetId)
              .catchError((e) => null,
                  test: (e) => e is AssetNotFoundException);
        })
        .where((f) => f != null);
    return Future.wait(initializerFutures).then((initializerAssets) {
      var imports = new StringBuffer();
      var calls = new StringBuffer();
      for (Asset asset in initializerAssets) {
        var id = asset.id;
        var importUri = getImportUri(id, input.id);
        if (importUri == null) continue;
        var prefix = assetIdToPrefix(id);
        imports.writeln("import '$importUri' as $prefix;");
        calls.writeln("  $prefix.initializeJavaScriptLibrary();");
      }

      var initMethod = 'initializeJavaScript() {\n$calls}\n';
      var insertImportOffset = getInsertImportOffset(library);
      var initMethodOffset = library.source.contents.data.length;
      transaction.edit(insertImportOffset, insertImportOffset, '$imports');
      transaction.edit(initMethodOffset, initMethodOffset, initMethod);
      var printer = transaction.commit();
      printer.build(input.id.path);
      transform.addOutput(new Asset.fromString(input.id, printer.text));
    });
  }
}

final illegalIdRegex = new RegExp(r'[^a-zA-Z0-9_]');

String assetIdToPrefix(AssetId id) =>
    '_js__${id.package}__${id.path.replaceAll(illegalIdRegex, '_')}';

// TODO(justinfagnani): put this in code_transformers ?
String getImportUri(AssetId importId, AssetId from) {
  if (importId.path.startsWith('lib/')) {
    // we support package imports
    return "package:${importId.package}/${importId.path.substring(4)}";
  } else if (importId.package == from.package) {
    // we can support relative imports
    return path.relative(importId.path, from: path.dirname(from.path));
  }
  // cannot import
  return null;
}
