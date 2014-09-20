// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.js_initializer_generator;

import 'package:js/src/js_elements.dart';
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

final _logger = new Logger('js.transformer.js_initializer_generator');

const JS_PREFIX = '__package_js_impl__';
const JS_THIS_REF = '__js_this_ref__';

class JsInitializerGenerator {
  final String libraryName;
  final String libraryPath;
  final JsElements jsElements;

  final buffer = new StringBuffer();

  JsInitializerGenerator(this.libraryName, this.libraryPath, this.jsElements);

  /**
   * Returns the transformed source.
   */
  String generate() {
    jsElements.exportedLibraries.values.forEach((l) {
      buffer.writeln("_export_${l.getPath('_')}(dart);");
    });
    jsElements.exportedLibraries.values.forEach(_generateLibraryExportFunction);
    return buffer.toString();
  }

  _generateLibraryExportCall(ExportedLibrary library) {
    buffer.writeln("  _export_${library.getPath('_')}(lib);");
  }

  _generateLibraryExportFunction(ExportedLibrary library) {
    buffer.writeln(
'''

function _export_${library.getPath('_')}(parent) {
  var lib = parent.${library.name} = {};
''');

    library.declarations.values.forEach(_generateDeclarationExportCall);
    library.children.values.forEach(_generateLibraryExportCall);

    buffer.writeln('}');

    library.children.values.forEach(_generateLibraryExportFunction);
    library.declarations.values.forEach(_generateDeclarationExport);
  }

  void _generateDeclarationExportCall(ExportedElement element) {
    if (element is ExportedClass) {
      buffer.writeln("  _export_${element.getPath('_')}(lib);");
    }
    // TODO: add functions and variables
  }

  void _generateDeclarationExport(ExportedElement element) {
    if (element is ExportedClass) {
      _generateClass(element);
    }
  }

  void _generateClass(ExportedClass c) {
    buffer.writeln(
'''

function _export_${c.getPath('_')}(parent) {
  var constructor = parent.${c.name} = function _${c.name}() {
    this.__dart_object__ = constructor._new();
  };
  constructor.prototype = Object.create(dart.Object.prototype);
  constructor.prototype.constructor = constructor;
  constructor._wrapDartObject = function(dartObject) {
    var o = Object.create(constructor.prototype);
    o.__dart_object__ = dartObject;
    return o;
  };

''');

    c.children.values
        .where((e) => e is ExportedConstructor)
        .forEach(_generateConstructor);

    buffer.writeln("}");
  }

  void _generateConstructor(ExportedConstructor c) {
    if (c.name == '') return;
    var constructorName = '_new_${c.name}';

    var dartParameters = _getDartParameters(c.parameters);
    var jsParameters = _getJsParameters(c.parameters);
    var namedPart = c.name == '' ? '' : '.${c.name}';
    buffer.writeln(
'''
  constructor.${c.name} = function _${c.name}($jsParameters) {
    this.__dart_object__ = constructor.$constructorName($jsParameters);
  }
  constructor.${c.name}.prototype = constructor.prototype;
''');
    }

  String _getJsParameters(List<ExportedParameter> parameters,
      {bool withThis: false}) {
    var requiredParameters = parameters
        .where((p) => p.kind == ParameterKind.REQUIRED)
        .map((p) => p.name);
    var positionalParameters = parameters
        .where((p) => p.kind == ParameterKind.POSITIONAL)
        .map((p) => p.name);
    var namedParameters = parameters
        .where((p) => p.kind == ParameterKind.NAMED)
        .map((p) => p.name);
    var jsParameterList = withThis ? [JS_THIS_REF] : [];
    jsParameterList.addAll(requiredParameters);
    var jsParameters = jsParameterList.join(', ');
    if (positionalParameters.isNotEmpty) {
      jsParameters += ', [' + positionalParameters.join(', ') + ']';
    } else if (namedParameters.isNotEmpty) {
      jsParameters += ', [__js_named_parameters_map__]';
    }
    return jsParameters;
  }

  String _getDartParameters(List<ExportedParameter> parameters) {
    var requiredParameters = parameters
        .where((p) => p.kind == ParameterKind.REQUIRED)
        .map((p) => p.name);
    var positionalParameters = parameters
        .where((p) => p.kind == ParameterKind.POSITIONAL)
        .map((p) => p.name);
    var namedParameters = parameters
        .where((p) => p.kind == ParameterKind.NAMED)
        .map((p) => p.name);
    var dartNamedParameters = namedParameters.map((name) =>
        "${name}: _getOptionalArg(__js_named_parameters_map__, '${name}')");
    var dartParameters = concat([
            requiredParameters,
            positionalParameters,
            dartNamedParameters])
        .join(', ');

    return dartParameters;
  }

}
