// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.scanning_visitor;

import 'dart:collection';

import 'package:analyzer/src/generated/element.dart';
import 'package:logging/logging.dart';

final _logger = new Logger('js.transformer.visitor');

class ExportState {
  static const ExportState NONE = const ExportState(0);
  static const ExportState EXPORTED = const ExportState(1);
  static const ExportState EXCLUDED = const ExportState(2);

  final int _state;
  const ExportState(this._state);
}

/**
 * Visits the elements in a single library, collecting information about
 * @Exported() elements and JsInterfaces.
 */
class ScanningVisitor extends RecursiveElementVisitor {
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final ClassElement jsInterfaceClass;
  final Set<ClassElement> jsInterfaces = new Set<ClassElement>();
  final Set<Element> exportedElements = new Set<Element>();
  final Set<Element> noExportedElements = new Set<Element>();

  final LibraryElement jsLibrary;
  final LibraryElement entryLibrary;
  final Queue<ExportState> exportStateStack = new Queue<ExportState>();

  ScanningVisitor(
      jsLibrary,
      this.entryLibrary)
      : this.jsLibrary = jsLibrary,
        jsInterfaceClass = jsLibrary.getType('JsInterface'),
        exportClass = jsLibrary.getType('Export'),
        noExportClass = jsLibrary.getType('NoExport') {
    assert(jsLibrary != null);
    assert(entryLibrary != null);
  }

  // TODO: do this outside the visitor
  bool get needsTransform => entryLibrary.visibleLibraries.contains(jsLibrary);

  @override
  @override
  visitLibraryElement(LibraryElement element) {
    // We don't visit other libraries, since this transformer runs on each
    // library separately. We also only run on libraries that have
    // JsInterface and/or Export available.
    if (element == entryLibrary && needsTransform) {
      final exportState = hasExportAnnotation(element) ? ExportState.EXPORTED
          : ExportState.NONE;

      if (exportState == ExportState.EXPORTED) {
        exportedElements.add(element);
      }
      if (hasNoExportAnnotation(element)) {
        _logger.warning("@NoExport() not allowed on libraries");
      }
      exportStateStack.add(exportState);
      super.visitLibraryElement(element);
      exportStateStack.removeLast();
      assert(exportStateStack.isEmpty);
    }
  }

  @override
  visitClassElement(ClassElement element) {
    if (isJsInterface(element)) {
      jsInterfaces.add(element);
    }

    final exportState = _maybeExportLibraryMember(element);
    if (exportState == ExportState.EXPORTED) {
      exportStateStack.add(exportState);
      super.visitClassElement(element);
      exportStateStack.removeLast();
    }
  }

  @override
  visitTopLevelVariableElement(TopLevelVariableElement element) {
    _maybeExportLibraryMember(element);
  }

  @override
  visitFunctionElement(FunctionElement element) {
    _maybeExportLibraryMember(element);
  }

  @override
  visitConstructorElement(ConstructorElement element) {
    _maybeExportClassMember(element);
  }

  @override
  visitMethodElement(MethodElement element) {
    _maybeExportClassMember(element);
  }

  visitFieldElement(FieldElement element) {
    _maybeExportClassMember(element);
  }

  ExportState _maybeExportLibraryMember(Element element) {
    final exportState = hasExportAnnotation(element) ? ExportState.EXPORTED
        : hasNoExportAnnotation(element) ? ExportState.EXCLUDED
        : exportStateStack.last;

    if (exportState == ExportState.EXPORTED) {
      exportedElements.add(element);
      exportedElements.add(element.library);
    }
    return exportState;
  }

  ExportState _maybeExportClassMember(ClassMemberElement element) {
    final exportState = hasNoExportAnnotation(element) ? ExportState.EXCLUDED
        : exportStateStack.last;
    if (exportState == ExportState.EXPORTED) {
      exportedElements.add(element);
    }
    return exportState;
  }

  /*
   * Determines whether a class directly extends JsInterface.
   */
  bool isJsInterface(ClassElement e) {
    if (e.isPrivate) return false;
    bool isJsInterface = false;

    if (e.allSupertypes.contains(jsInterfaceClass.type)) {
      isJsInterface = true;
    }

    if (isJsInterface) {
      for (var m in e.metadata) {
        if (m.element.kind == ElementKind.CONSTRUCTOR) {
          if (m.element.enclosingElement == exportClass) {
            _logger.warning('@Export() on a JsInterface');
          } else if (m.element.enclosingElement == noExportClass) {
            _logger.warning('@NoExport() on a JsInterface');
          }
        }
      }
    }
    return isJsInterface;
  }

  bool hasExportAnnotation(Element e) => e.metadata.any((m) =>
      m.element.kind == ElementKind.CONSTRUCTOR &&
      m.element.enclosingElement == exportClass);

  bool hasNoExportAnnotation(Element e) => e.metadata.any((m) =>
      m.element.kind == ElementKind.CONSTRUCTOR &&
      m.element.enclosingElement == noExportClass);
}
