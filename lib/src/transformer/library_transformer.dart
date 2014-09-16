// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.library_transformer;

import 'dart:async';

import 'package:analyzer/analyzer.dart' show Directive, PartOfDirective,
    parseCompilationUnit, parseDirectives;
import 'package:barback/barback.dart' show Asset, AssetId, Transform,
    Transformer;
import 'package:code_transformers/resolver.dart' show Resolver, Resolvers,
    ResolverTransformer;
import 'package:logging/logging.dart' show Logger;

import 'scanning_visitor.dart';
import 'js_proxy_generator.dart';
import 'package:js/src/transformer/js_initializer_generator.dart';

final _logger = new Logger('js.transformer.interface_transformer');

class LibraryTransformer extends Transformer with ResolverTransformer {
  @override
  final Resolvers resolvers;

  LibraryTransformer(this.resolvers);

  @override
  Future<bool> isPrimary(AssetId id) => new Future.value(
      id.extension == '.dart' &&
      !(id.package == 'js' && id.path.startsWith('lib')));

  Future<bool> shouldApplyResolver(Asset asset) {
    return asset.readAsString().then((contents) {
      var cu = parseDirectives(contents, suppressErrors: true);
      var isPart = cu.directives.any((Directive d) => d is PartOfDirective);
      return !isPart;
    });
  }

  @override
  applyResolver(Transform transform, Resolver resolver) {
    var input = transform.primaryInput;
    var library = resolver.getLibrary(transform.primaryInput.id);
    var jsLibrary = resolver.getLibraryByName('js');
    var jsMetadataLibrary = resolver.getLibraryByName('js.metadata');

    if (jsLibrary == null || !library.visibleLibraries.contains(jsLibrary)) {
      return;
    }

    var transaction = resolver.createTextEditTransaction(library);

    var scanningVisitor =
        new ScanningVisitor(jsLibrary, jsMetadataLibrary, library);
    library.accept(scanningVisitor);

    var proxyGenerator = new JsProxyGenerator(
        input.id,
        scanningVisitor.jsProxies,
        library,
        jsLibrary,
        jsMetadataLibrary,
        transaction);
    var newSource = proxyGenerator.generate();
    for (var assetId in newSource.keys) {
      var source = newSource[assetId];
      var asset = new Asset.fromString(assetId, source);
      transform.addOutput(asset);
    }

    var initializerGenerator = new JsInitializerGenerator(
        library.name,
        input.id.path,
        scanningVisitor.jsElements);

    var initializerId = input.id.addExtension('__init_js__.dart');

    String initializerSource = initializerGenerator.generate();
    var initializerAsset =
        new Asset.fromString(initializerId, initializerSource);
    transform.addOutput(initializerAsset);
  }
}
