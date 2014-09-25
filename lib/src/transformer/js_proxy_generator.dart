// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.js_proxy_generator;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:barback/barback.dart';
import 'package:js/src/metadata.dart';
import 'package:js/src/transformer/utils.dart';
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart' show max, concat;
import 'package:source_maps/refactor.dart';

final _logger = new Logger('js.transformer.js_proxy_generator');

const JS_PREFIX = '__package_js_impl__';

class JsProxyGenerator {
  final AssetId inputId;
  final ClassElement jsInterfaceClass;
  final ClassElement jsProxyClass;
  final ClassElement exportClass;
  final ClassElement noExportClass;

  final LibraryElement library;
  final LibraryElement jsLibrary;
  final TextEditTransaction transaction;

  /// The list of classes to generate proxy implementations for
  final Iterable<ClassElement> jsProxies;
  final InheritanceManager inheritanceManager;

  var generatedMembers = new Set<Element>();

  JsProxyGenerator(
    this.inputId,
    this.jsProxies,
    LibraryElement library,
    LibraryElement jsLibrary,
    LibraryElement jsMetadataLibrary,
    this.transaction)
      : library = library,
        jsLibrary = jsLibrary,
        jsInterfaceClass = getImplLib(jsLibrary).getType('JsInterface'),
        jsProxyClass = jsMetadataLibrary.getType('JsProxy'),
        exportClass = jsMetadataLibrary.getType('Export'),
        noExportClass = jsMetadataLibrary.getType('NoExport'),
        inheritanceManager = new InheritanceManager(library) {
    assert(jsLibrary != null);
    assert(library != null);
    assert(jsInterfaceClass != null);
    assert(jsProxyClass != null);
    assert(exportClass != null);
    assert(noExportClass != null);
  }

  /**
   * Returns the transformed source.
   */
  Map<AssetId, String> generate() {
    _addImports();
    jsProxies.forEach(_generateProxyImplementation);
    var printer = transaction.commit();
    printer.build('test.dart');
    var transformedLib = printer.text;
    return <AssetId, String>{
      inputId: transformedLib,
    };
  }

  void _addImports() {
    var insertImportOffset = getInsertImportOffset(library);
    transaction.edit(insertImportOffset, insertImportOffset,
        "\nimport 'package:js/src/js_impl.dart' as $JS_PREFIX;");
  }

  void _generateProxyImplementation(ClassElement proxy) {
    final proxyAnnotation = getProxyAnnotation(proxy, jsProxyClass);

    if (proxyAnnotation == null) return;

    final bool isGlobal = proxyAnnotation.global == true;
    final String jsConstructor = proxyAnnotation.constructor;

    if (!isGlobal && jsConstructor == null) {
      _logger.severe("JsProxy annotation must have either a global or a"
          " constructor parameter");
    }

    // TODO: check other constructors?
    _checkCreatedConstructor(proxy);
    var hasFactory = _replaceFactoryConstructor(proxy, proxyAnnotation);

    if (isGlobal && !hasFactory) {
      _logger.severe("global objects must have factory constructors");
    }

    _generateAbstractMembers(proxy);
  }

  bool _replaceFactoryConstructor(ClassElement proxy, JsProxy proxyAnnotation) {
    final name = proxy.name;
    final factoryConstructor = _getFactoryConstructor(proxy);
    final bool isGlobal = proxyAnnotation.global;
    final String jsConstructor = proxyAnnotation.constructor;

    if (factoryConstructor == null) return false;

    var body = factoryConstructor.node.body;
    var begin = body.offset;
    var end = body.end;

    if (body is! ExpressionFunctionBody ||
        body.expression is! InstanceCreationExpression) {
      _logger.severe('JsInterface factory constructors must be expressions'
          ' that call new JsInterface()');
    }
    InstanceCreationExpression expr = body.expression;
    var args = expr.argumentList.arguments;
    var implType = args[0];
    var ctorArgs = args[1];

    if (isGlobal) {
      if (factoryConstructor.parameters.isNotEmpty) {
        _logger.severe('global proxy constructors must not have parameters');
      }
      var offset = factoryConstructor.node.offset;
      transaction.edit(offset, offset, 'static $name _instance;\n  ');
      transaction.edit(begin, end, '=> (_instance != null) ? _instance '
          ': _instance = new $implType.created($JS_PREFIX.context);');
    } else {
      var parameterList = factoryConstructor.parameters
          .map((p) => p.displayName)
          .join(', ');
      transaction.edit(begin, end, '=> new $implType.created('
          'new JsObject($JS_PREFIX.context["$jsConstructor"], '
              '[$parameterList]));');
    }
    return true;
  }

  void _generateAbstractMembers(ClassElement proxy) {
    var memberMap =
        inheritanceManager.getMapOfMembersInheritedFromInterfaces(proxy);

    for (var i = 0; i < memberMap.size; i++) {
      var memberKey = memberMap.getKey(i);
      var member = memberMap.getValue(i);

      if (generatedMembers.contains(member) || !member.isAbstract) continue;
      generatedMembers.add(member);

      if (member is PropertyAccessorElement) {
        if (member.isGetter) {
          _generateGetter(member);
        } else if (member.isSetter) {
          _generateSetter(member);
        }
      } else if (member is MethodElement) {
        _generateMethod(member);
      }
    }

  }

  void _generateMethod(MethodElement a) {
    var name = a.displayName;
    if (!a.isStatic) {
      var returnType = a.returnType;

      var jsParameterList = new StringBuffer();

      var parameterList = a.parameters
          .map((p) => '$JS_PREFIX.toJs(${p.name})')
          .join(', ');

      MethodDeclaration m = a.node;
      var offset = m.body.offset;
      var end = m.body.end;
      if (a.returnType.name == 'void') {
        transaction.edit(offset, end, " { $JS_PREFIX.toDart("
            "$JS_PREFIX.toJs(this).callMethod('$name', [$parameterList])); }");
      } else {
        transaction.edit(offset, end, " => $JS_PREFIX.toDart("
            "$JS_PREFIX.toJs(this).callMethod('$name', [$parameterList]))"
            " as ${a.returnType};");
      }
    }
  }

  void _generateSetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var parameter = a.parameters.single;
    var type = parameter.type;
    if (type == null) {
      _logger.severe("abstract JsInterface setters must have type annotations");
      return;
    }
    var parameterName = parameter.name;
    MethodDeclaration m = a.node;
    var offset = m.body.offset;
    var end = m.body.end;
    transaction.edit(offset, end, " { $JS_PREFIX.toJs(this)['$name']"
        " = $JS_PREFIX.toJs($parameterName); }");
  }

  void _generateGetter(PropertyAccessorElement a) {
    var name = a.displayName;
    var type = a.type.returnType;
    if (type == null) {
      _logger.severe("abstract JsInterface getters must have type annotations");
      return;
    }
    MethodDeclaration m = a.node;
    var offset = m.body.offset;
    var end = m.body.end;
    transaction.edit(offset, end, " => $JS_PREFIX.toDart("
        "$JS_PREFIX.toJs(this)['$name']) as $type;");
  }

  ConstructorElement _getFactoryConstructor(ClassElement interface) =>
      interface.constructors
      .firstWhere((c) => c.name == '' && c.isFactory, orElse: () => null);

  ConstructorElement _checkCreatedConstructor(ClassElement interface) =>
      interface.constructors.firstWhere(
          (c) => c.name == 'created' && !c.isFactory,
          orElse: () {
            _logger.severe("JsInterface subclasses must have a"
                "generative constructor named 'created'");
            return null;
          });

}
