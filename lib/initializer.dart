// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.initializer;

import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer, TransformerGroup;
import 'package:code_transformers/resolver.dart';
import 'package:js/src/transformer/entry_point_transformer.dart';
import 'package:js/src/transformer/html_transformer.dart';

import 'src/transformer/mock_sdk.dart' as mock_sdk show sources;

class InitializerTransformerGroup implements TransformerGroup {
  final Resolvers _resolvers;

  final Iterable<Iterable> phases;

  InitializerTransformerGroup(Resolvers resolvers)
      : _resolvers = resolvers,
        phases = [
          [new EntryPointTransformer(resolvers), new HtmlTransformer()],
        ];

  InitializerTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new Resolvers.fromMock(mock_sdk.sources));
}
