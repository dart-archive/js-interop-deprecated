// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.utils;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/analyzer.dart';
import 'package:js/src/metadata.dart';
import 'package:quiver/iterables.dart' show max;

const String INITIALIZER_SUFFIX = "__init_js__.dart";

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
