// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.scanning_visitor;

import 'package:analyzer/src/generated/element.dart' hide DartType;
import 'package:analyzer/src/generated/element.dart' as analyzer show DartType;
import 'package:analyzer/src/generated/utilities_dart.dart' as analyzer
    show ParameterKind;
import 'package:logging/logging.dart';
import 'package:js/src/js_elements.dart';
import 'package:js/src/transformer/utils.dart';

final _logger = new Logger('js.transformer.visitor');

class ExportState {
  static const ExportState NONE = const ExportState(0);
  static const ExportState EXPORTED = const ExportState(1);
  static const ExportState EXCLUDED = const ExportState(2);

  final int _state;
  const ExportState(this._state);
  String toString() => '$_state';
}

/**
 * Visits the elements in a single library, collecting information about
 * @Exported() elements and JsInterfaces.
 */
class ScanningVisitor extends RecursiveElementVisitor {
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final ClassElement jsInterfaceClass;
  final ClassElement jsProxyClass;
  final ClassElement jsifyClass;

  // This is neccessary for code-generating proxy implementations
  final Set<ClassElement> jsProxies = new Set<ClassElement>();

  final JsElements jsElements = new JsElements();

  final LibraryElement jsLibrary;
  final LibraryElement entryLibrary;
  ExportState _exportState;

  ScanningVisitor(
      jsLibrary,
      LibraryElement jsMetadataLibrary,
      this.entryLibrary)
      : this.jsLibrary = jsLibrary,
        jsInterfaceClass = getImplLib(jsLibrary).getType('JsInterface'),
        jsProxyClass = jsMetadataLibrary.getType('JsProxy'),
        exportClass = jsMetadataLibrary.getType('Export'),
        noExportClass = jsMetadataLibrary.getType('NoExport'),
        jsifyClass = jsMetadataLibrary.getType('Jsify') {
    assert(jsLibrary != null);
    assert(entryLibrary != null);
    assert(jsInterfaceClass != null);
    assert(jsProxyClass != null);
    assert(exportClass != null);
    assert(noExportClass != null);
    assert(jsifyClass != null);
  }

  @override
  visitLibraryElement(LibraryElement element) {
    // We don't visit other libraries, since this transformer runs on each
    // library separately. We also only run on libraries that have
    // JsInterface and/or Export available.
    if (element == entryLibrary) {
      _exportState = hasExportAnnotation(element) ? ExportState.EXPORTED
          : ExportState.NONE;

      if (_exportState == ExportState.EXPORTED) {
        var name = element.name;
        jsElements.getLibrary(name);
      }
      if (hasNoExportAnnotation(element)) {
        _logger.warning("@NoExport() not allowed on libraries");
      }
      super.visitLibraryElement(element);
    }
  }

  @override
  visitClassElement(ClassElement element) {
    var proxyAnnotation = getProxyAnnotation(element, jsProxyClass);
    if (proxyAnnotation != null) {
      jsProxies.add(element);
      jsElements.proxies.add(new Proxy(element.name, proxyAnnotation.global,
          proxyAnnotation.constructor));
      // proxies aren't exported
      return;
    }

    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED) {
      var library = jsElements.getLibrary(element.library.name);
      var name = element.name;
      var c = new ExportedClass(name, library);
      library.declarations[name] = c;
    }
    super.visitClassElement(element);
    _restoreExportState(previousState);
  }

  @override
  visitTopLevelVariableElement(TopLevelVariableElement element) {
    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED) {
      var library = jsElements.getLibrary(element.library.name);
      var name = element.name;
      var v = new ExportedTopLevelVariable(name, library);
      library.declarations[name] = v;
    }
    _restoreExportState(previousState);
  }

  @override
  visitFunctionElement(FunctionElement element) {
    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED) {
      var library = jsElements.getLibrary(element.library.name);
      var name = element.name;
      var parameters = element.parameters
          .map((p) =>
              new ExportedParameter(
                  p.name,
                  _getParameterKind(p.parameterKind),
                  new DartType(p.type.name)))
          .toList();
      var jsifyReturn = hasAnnotation(element, jsifyClass);
      var v = new ExportedFunction(name, library, parameters,
          jsifyReturn: jsifyReturn);
      library.declarations[name] = v;
    }
    _restoreExportState(previousState);
  }

  @override
  visitConstructorElement(ConstructorElement element) {
    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED) {
      var library = jsElements.getLibrary(element.library.name);
      var clazz = library.declarations[element.enclosingElement.name];
      assert(clazz is ExportedClass);
      var name = element.name;
      var parameters = element.parameters
          .map((p) =>
              new ExportedParameter(
                  p.name,
                  _getParameterKind(p.parameterKind),
                  new DartType(p.type.name)))
          .toList();
      var c = new ExportedConstructor(name, clazz, parameters);
      clazz.children[name] = c;
    }
    _restoreExportState(previousState);
  }

  ParameterKind _getParameterKind(analyzer.ParameterKind kind) {
    if (kind == analyzer.ParameterKind.REQUIRED) {
      return ParameterKind.REQUIRED;
    }
    if (kind == analyzer.ParameterKind.POSITIONAL) {
      return ParameterKind.POSITIONAL;
    }
    if (kind == analyzer.ParameterKind.NAMED) {
      return ParameterKind.NAMED;
    }
    assert(false);
    return null;
  }

  @override
  visitMethodElement(MethodElement element) {
    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED && element.isPublic) {
      var library = jsElements.getLibrary(element.library.name);
      var clazz = library.declarations[element.enclosingElement.name];
      assert(clazz is ExportedClass);
      var name = element.name;
      var parameters = element.parameters
          .map((p) =>
              new ExportedParameter(
                  p.name,
                  _getParameterKind(p.parameterKind),
                  new DartType(p.type.name)))
          .toList();
      var jsifyReturn = hasAnnotation(element, jsifyClass);
      var c = new ExportedMethod(name, clazz, parameters,
          isStatic: element.isStatic, jsifyReturn: jsifyReturn);
      clazz.children[name] = c;
    }
    _restoreExportState(previousState);
  }

  visitFieldElement(FieldElement element) {
    final previousState = _updateExportState(element);
    if (_exportState == ExportState.EXPORTED && element.isPublic) {
      var library = jsElements.getLibrary(element.library.name);
      var clazz = library.declarations[element.enclosingElement.name];
      assert(clazz is ExportedClass);
      var name = element.name;
      var jsify = hasAnnotation(element, jsifyClass);
      if (element.getter != null && !element.getter.isSynthetic) {
        jsify = hasAnnotation(element.getter, jsifyClass);
      }
      var c = new ExportedProperty(name, clazz,
          hasGetter: element.getter != null,
          hasSetter: element.setter != null,
          isStatic: element.isStatic,
          jsify: jsify);
      clazz.children[name] = c;
    }
    _restoreExportState(previousState);
  }

  /**
   * Sets the current ExportState based on [element] and returns the previous
   * ExportState for saving.
   */
  ExportState _updateExportState(Element element) {

    final noExport = hasNoExportAnnotation(element);
    if (noExport && _exportState != ExportState.EXPORTED) {
      // TODO(justinfagnani): figure out how to print source info.
      // this fails for StringSource
//      var location = element.location;
//      var path = location.components;
      _logger.warning("Unnecessary @NoExport annotation");
    }

    var previousState = _exportState;
    bool include = hasExportAnnotation(element);
    bool exclude = noExport;
    if (element is ClassElement) {
      exclude = exclude || element.isAbstract
          || element.allSupertypes.contains(jsInterfaceClass);
    } else if (element is MethodElement) {
      exclude = exclude || element.isAbstract;
    }
    _exportState =
        include && !exclude ? ExportState.EXPORTED
        : exclude ? ExportState.EXCLUDED
        : this._exportState;
    return previousState;
  }

  void _restoreExportState(ExportState previousState) {
    _exportState = previousState;
  }


  /*
   * TODO(justinfagnani);
   *
   * This might not be relevant for v0, but maybe you'd like to copy the logic
   * we have in smoke for this:
   * https://code.google.com/p/dart/source/browse/branches/bleeding_edge/dart/pkg/smoke/lib/codegen/recorder.dart?r=38575#331
   *
   * That would give you:
   *  - support for checking also subclases of the type
   *  - support for constants defined in terms of the type (e.g. if we define
   *    `const export = const Export();`)
   */
  bool hasExportAnnotation(Element e) => e.metadata.any((m) =>
      m.element.kind == ElementKind.CONSTRUCTOR &&
      m.element.enclosingElement == exportClass);

  bool hasNoExportAnnotation(Element e) => e.metadata.any((m) =>
      m.element.kind == ElementKind.CONSTRUCTOR &&
      m.element.enclosingElement == noExportClass);
}
