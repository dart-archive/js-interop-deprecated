// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.js_initializer_generator;

import 'package:js/src/js_elements.dart';
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

final _logger = new Logger('js.transformer.js_initializer_generator');

const JS_PREFIX = '__package_js_impl__';

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
    buffer.write(
'''
library ${libraryName}__init_js__;

import '${libraryPath}';
import 'package:js/src/js_impl.dart' as $JS_PREFIX;

initializeJavaScriptLibrary() {
''');

    jsElements.proxies.forEach((Proxy proxy) {
      if (proxy.constructor == null) return;
      var name = proxy.name;
      buffer.writeln("  $JS_PREFIX.registerFactoryForJsConstructor("
          "$JS_PREFIX.context['${proxy.constructor}'], "
          "($JS_PREFIX.JsObject o) => new $name.created(o));");
    });

    buffer.writeln("  var lib = $JS_PREFIX.context['dart'];");

    jsElements.exportedLibraries.values.forEach(_generateLibraryExportCall);

    buffer.writeln('}');

    jsElements.exportedLibraries.values.forEach(_generateLibraryExportMethod);

    return buffer.toString();
  }

  _generateLibraryExportCall(ExportedLibrary library) {
    buffer.writeln("  _export_${library.getPath('_')}(lib);");
  }

  _generateLibraryExportMethod(ExportedLibrary library) {
    buffer.writeln(
'''

void _export_${library.getPath('_')}($JS_PREFIX.JsObject parent) {
  JsObject lib = parent['${library.name}'];
''');

    library.declarations.values.forEach(_generateDeclarationExportCall);
    library.children.values.forEach(_generateLibraryExportCall);

    buffer.writeln('}');

    library.children.values.forEach(_generateLibraryExportMethod);
    library.declarations.values.forEach(_generateDeclarationExport);
  }

  void _generateDeclarationExportCall(ExportedElement element) {
    if (element is ExportedClass) {
      buffer.writeln("  _export_${element.getPath('_')}(lib);");
    }
  }

  void _generateDeclarationExport(ExportedElement element) {
    if (element is ExportedClass) {
      _generateClass(element);
    }
  }

  void _generateClass(ExportedClass c) {
    buffer.writeln(
'''

void _export_${c.getPath('_')}($JS_PREFIX.JsObject lib) {
  var constructor = parent['${c.name}'];
  $JS_PREFIX.registerJsConstructorForType(${c.name}, constructor['_wrapDartObject']);
  var prototype = constructor['prototype'];
''');

    c.children.values.forEach(_generateClassMember);

    buffer.writeln("}");
  }

  void _generateClassMember(ExportedElement e) {
    if (e is ExportedConstructor) {
      _generateConstructor(e);
    } else if (e is ExportedMethod) {
      _generateMethod(e);
    }
  }

  void _generateConstructor(ExportedConstructor c) {
    var constructorName = c.name == '' ? '_new' : c.name;
    var dartParameters = _getDartParameters(c.parameters);
    var jsParameters = _getJsParameters(c.parameters);
    var namedPart = c.name == '' ? '' : '.${c.name}';
    buffer.writeln("  constructor['$constructorName'] = ($jsParameters) => "
        "new ${c.parent.name}$namedPart($dartParameters);");
  }

  void _generateMethod(ExportedMethod c) {
    var constructorName = c.name == '' ? '_new' : c.name;
    var dartParameters = _getDartParameters(c.parameters);
    var jsParameters = _getJsParameters(c.parameters);
    buffer.write(
'''

  // method ${c.name}
  prototype['${c.name}'] = new js.JsFunction.withThis(($jsParameters) {
    return  __js_this_ref__.${c.name}($dartParameters);
  });
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
    var jsParameterList = withThis ? ['__js_this_ref__'] : [];
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
