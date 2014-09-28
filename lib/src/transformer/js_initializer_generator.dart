// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.js_initializer_generator;

import 'package:js/src/js_elements.dart';
import 'package:js/src/transformer/utils.dart';
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

final _logger = new Logger('js.transformer.js_initializer_generator');

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
    jsElements.exportedLibraries.values.forEach(_generateLibraryExportFunction);
    return buffer.toString();
  }

  _generateLibraryExportCall(ExportedLibrary library) {
    buffer.writeln("  _export_${library.getPath('_')}(lib);");
  }

  _generateLibraryExportFunction(ExportedLibrary library) {
    buffer.writeln(
'''
// library ${library.name}
(function (ns) {
  var lib = ns;
  ${library.name.split('.').map((p) => '"$p"').toList()}.forEach(function (s) {
    lib = lib[s] = lib[s] || {};
  });
''');

    library.declarations.values.forEach(_generateDeclarationExport);
    buffer.writeln('})(window.dart);');

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
    var jsParameters = '';
    var defaultConstructor = c.children[''];
    if (defaultConstructor != null) {
      jsParameters = formatParameters(defaultConstructor.parameters,
          _jsParameterFormatter);
    }

    buffer.writeln(
'''
  // class ${c.name}
  (function(parent) {
    var constructor = parent.${c.name} = function _${c.name}($jsParameters) {
      this.$DART_OBJECT_PROPERTY = constructor._new($jsParameters);
    };
    constructor.prototype = Object.create(dart.Object.prototype);
    constructor.prototype.constructor = constructor;
    constructor._wrapDartObject = function(dartObject) {
      var o = Object.create(constructor.prototype);
      o.$DART_OBJECT_PROPERTY = dartObject;
      return o;
    };
''');

    c.children.values
        .where((e) => e is ExportedConstructor)
        .forEach(_generateConstructor);

    buffer.writeln("  })(lib);");
  }

  void _generateConstructor(ExportedConstructor c) {
    if (c.name == '') return;
    var constructorName = '_new_${c.name}';

    var jsParameters = formatParameters(c.parameters, _jsParameterFormatter);
    var namedPart = c.name == '' ? '' : '.${c.name}';
    buffer.writeln(
'''
    constructor.${c.name} = function _${c.name}($jsParameters) {
      this.$DART_OBJECT_PROPERTY = constructor.$constructorName($jsParameters);
    }
    constructor.${c.name}.prototype = constructor.prototype;
''');
  }
}


_jsParameterFormatter(requiredParameters, optionalParameters, namedParameters) {
  var parameters = concat([requiredParameters, optionalParameters]).toList();
  if (namedParameters.isNotEmpty) {
    parameters.add(JS_NAMED_PARAMETERS);
  }
  return parameters.join(', ');
}
