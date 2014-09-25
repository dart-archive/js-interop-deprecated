// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.utils;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:barback/barback.dart';
import 'package:js/src/metadata.dart';
import 'package:path/path.dart' as path;
import 'package:quiver/iterables.dart' show max;

const String DART_INITIALIZER_SUFFIX = "__init_js__.dart";
const String JS_INITIALIZER_SUFFIX = "__init_js__.js";

LibraryElement getEnvironementImplLib(LibraryElement jsLib) =>
    jsLib.exportedLibraries
        .singleWhere((l) => l.name == 'js.mirrors' || l.name == 'js.static');

LibraryElement getMetadataLib(LibraryElement jsLib) =>
    getEnvironementImplLib(jsLib)
        .exportedLibraries
        .singleWhere((l) => l.name == 'js.metadata');

LibraryElement getImplLib(LibraryElement jsLib) =>
    getEnvironementImplLib(jsLib)
        .exportedLibraries
        .singleWhere((l) => l.name == 'js.impl');

JsProxy getProxyAnnotation(ClassElement interface, ClassElement jsProxyClass) {
  var node = interface.node;
  for (Annotation a in node.metadata) {
    var e = a.element;
    if (e is ConstructorElement && e.type.returnType == jsProxyClass.type) {
      bool global;
      String constructor;
      for (Expression e in a.arguments.arguments) {
        if (e is NamedExpression) {
          if (e.name.label.name == 'global' && e.expression is BooleanLiteral) {
            BooleanLiteral b = e.expression;
            global = b.value;
          } else if (e.name.label.name == 'constructor' &&
              e.expression is StringLiteral) {
            StringLiteral s = e.expression;
            constructor = s.stringValue;
          }
        }
      }
      return new JsProxy(global: global, constructor: constructor);
    }
  }
  return null;
}

int getInsertImportOffset(LibraryElement library) {
  var insertImportOffset = 0;
  if (library.imports.isEmpty) {
    LibraryDirective libraryDirective =
        library.definingCompilationUnit.node.directives
            .firstWhere((d) => d is LibraryDirective, orElse: () => null);
    if (libraryDirective != null) {
      insertImportOffset = libraryDirective.end;
    }
  } else {
    insertImportOffset = max(library.definingCompilationUnit.node.directives
        .where((d) => d is ImportDirective)
        .map((ImportDirective e) => e.end));
    if (insertImportOffset == null) insertImportOffset = 0;
  }
  return insertImportOffset;
}


final illegalIdRegex = new RegExp(r'[^a-zA-Z0-9_]');

String assetIdToPrefix(AssetId id) =>
    '_js__${id.package}__${id.path.replaceAll(illegalIdRegex, '_')}';

String assetIdToJsExportCall(AssetId id) =>
    '_export_${id.path.replaceAll(illegalIdRegex, '_')}(dart);';

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
