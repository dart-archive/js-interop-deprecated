// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.interface_generator;

import 'package:analyzer/src/generated/element.dart';
import 'package:source_maps/refactor.dart';
import 'package:logging/logging.dart';
import 'package:analyzer/analyzer.dart';

final _logger = new Logger('js.transformer.interface_generator');

class InterfaceGenerator {

  final ClassElement jsInterfaceClass;
  final ClassElement jsGlobalClass;
  final ClassElement jsConstructorClass;
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final LibraryElement library;
  final LibraryElement jsLibrary;
  final TextEditTransaction transaction;
  final StringBuffer implBuffer;

  /// The list of abstract classes to generate proxy implementations for
  final Iterable<ClassElement> jsInterfaces;

  InterfaceGenerator(
    this.jsInterfaces,
    this.library,
    LibraryElement jsLibrary,
    this.transaction)
      : jsLibrary = jsLibrary,
        jsInterfaceClass = jsLibrary.getType('JsInterface'),
        jsGlobalClass = jsLibrary.getType('JsGlobal'),
        jsConstructorClass = jsLibrary.getType('JsConstructor'),
        exportClass = jsLibrary.getType('Export'),
        noExportClass = jsLibrary.getType('NoExport'),
        implBuffer =  new StringBuffer();

  /**
   * Returns the generated concrete implemantions. This also triggers edits
   * on the supplied TextEditTransaction to replace factory constructors.
   */
  String generate() {
    jsInterfaces.forEach(generateClass);
    return implBuffer.toString();
  }

  void generateClass(ClassElement interface) {
    final interfaceName = interface.name;
    final implName = '${interfaceName}Impl';
    final bool isGlobal = _isGlobalInterface(interface);
    final factoryConstructor = _getFactoryConstructor(interface);
    final bool hasFactory = factoryConstructor != null;
    final String jsConstructor = _getJsConstructor(interface);

    if (hasFactory) {
      // if there's a factory there must be a generative ctor named _create
      final createConstructor = _getCreateConstructor(interface);
      if (createConstructor == null) {
        _logger.severe("When a factory constructor is defined, a "
            "generative constructor named _create must be defined as well");
      }

      // replace the factory constructor
      var body = factoryConstructor.node.body;
      var begin = body.offset;
      var end = body.end;

      if (isGlobal) {
        transaction.edit(begin, end, '=> new $implName._wrap(jsContext);');
      } else {
        // factory parameters
        var parameterList = factoryConstructor.parameters
            .map((p) => p.displayName)
            .join(', ');
        transaction.edit(begin, end, '=> new $implName._($parameterList);');
      }
    }

    if (isGlobal && !hasFactory) {
      _logger.severe("global objects must have factory constructors");
    }


    // add impl class
    implBuffer.write('''
    
    class $implName extends $interfaceName {
      final JsObject _obj;
    
      static $implName wrap(JsObject o) => new $implName._wrap(o);
    
      $implName._wrap(this._obj) : super${ hasFactory ? '._create' : ''}();
    
    ''');

    if (hasFactory && !isGlobal) {
      implBuffer.writeln('static final _ctor = jsContext["$jsConstructor"];');
      // parameters
      var parameterList = factoryConstructor.parameters
          .map((p) => '${p.type.displayName} ${p.displayName}')
          .join(', ');

      var jsParameterList = factoryConstructor.parameters
          .map((p) {
            var type = p.type;
            if (type.isSubtypeOf(jsInterfaceClass.type)) {
              return '${p.displayName}._obj';
            } else {
              return p.displayName;
            }
          })
          .join(', ');

      String newCall = 'new JsObject(_ctor, [$jsParameterList])';
      implBuffer.writeln('  $implName._($parameterList) : _obj = $newCall, super._create();');
    }

    for (PropertyAccessorElement a in interface.accessors) {
      if ((a.isAbstract || a.variable != null) && !a.isStatic) {
        if (a.isGetter) {
          _generateGetter(a);
        }
        if (a.isSetter) {
          _generateSetter(a);
        }
      }
    }

    for (MethodElement a in interface.methods) {
      _generateMethod(a, interfaceName);
    }

    implBuffer.write('}');
  }

  void _generateMethod(MethodElement a, String interfaceName) {
    var name = a.displayName;
    if (!a.isStatic && name != interfaceName) {
      var returnType = a.returnType;

      var parameterList = new StringBuffer();
      var jsParameterList = new StringBuffer();

      // parameters
      for (var p in a.parameters) {
        var type = p.type;
        parameterList.write('${type.displayName} ${p.displayName}');
        if (type.isSubtypeOf(jsInterfaceClass.type)) {
          // unwrap
          jsParameterList.write('${p.displayName}._obj');
        } else {
          jsParameterList.write('${p.displayName}');
        }
      }

      if (returnType.isSubtypeOf(jsInterfaceClass.type)) {
        var returnTypeImplName = '${returnType}Impl';
        implBuffer.writeln(
            '  ${a.returnType} $name($parameterList) => '
            'getWrapper(_obj.callMethod("$name", [$jsParameterList]) '
            'as JsObject, $returnTypeImplName._wrap) as $returnTypeImplName;');
      } else {
        implBuffer.writeln(
            '  ${a.returnType} $name($parameterList) => '
            '_obj.callMethod("$name", [$jsParameterList]);');
      }
    }
  }

  void _generateSetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var type = a.parameters[0].type;
    if (type.isSubtypeOf(jsInterfaceClass.type)) {
      implBuffer.writeln(
          '  void set $name(${a.parameters[0].type} v) => '
          '_obj["$name"] = v._obj;');
    } else {
      implBuffer.writeln(
          '  void set $name(${a.parameters[0].type} v) { _obj["$name"] = v; }');
    }
  }

  void _generateGetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var type = a.type.returnType;
    var typeImplName = '${type}Impl';
    if (type.isSubtypeOf(jsInterfaceClass.type)) {
      implBuffer.writeln(
          '  $type get $name => getWrapper(_obj["$name"], $typeImplName.wrap) '
          'as $type;');
    } else {
      // TODO: verify that $type is a primitive, List, JsObject or native object
      implBuffer.writeln('  $type get $name => _obj["$name"] as $type;');
    }
  }

  bool _isGlobalInterface(ClassElement interface) {
    for (var m in interface.metadata) {
      var e = m.element;
      if (e is ConstructorElement && e.type.returnType == jsGlobalClass.type) {
        return true;
      }
    }
    return false;
  }

  _getFactoryConstructor(ClassElement interface) => interface.constructors
      .firstWhere((c) => c.name == '' && c.isFactory, orElse: () => null);

  _getCreateConstructor(ClassElement interface) => interface.constructors
      .firstWhere((c) => c.name == '_create' && !c.isFactory,
      orElse: () => null);

  _getJsConstructor(ClassElement interface) {
    var node = interface.node;
    for (Annotation a in node.metadata) {
      var e = a.element;
      if (e is ConstructorElement && e.type.returnType == jsConstructorClass.type) {
        return (a.arguments.arguments[0] as StringLiteral).stringValue;
      }
    }
    return null;
  }

}