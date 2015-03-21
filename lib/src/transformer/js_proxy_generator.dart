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
import 'package:source_maps/refactor.dart';

final _logger = new Logger('js.transformer.js_proxy_generator');

const JS_PREFIX = '__package_js_impl__';

class JsProxyGenerator {
  final AssetId inputId;
  final ClassElement jsInterfaceClass;
  final ClassElement jsProxyClass;
  final ClassElement jsNameClass;
  final ClassElement exportClass;
  final ClassElement noExportClass;
  final ClassElement jsifyClass;

  final LibraryElement library;
  final LibraryElement jsLibrary;
  final TextEditTransaction transaction;

  /// The list of classes to generate proxy implementations for
  final Iterable<ClassElement> jsProxies;
  final InheritanceManager inheritanceManager;

  final generatedMembers = <ClassElement, Set<Element>>{};

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
        jsNameClass = jsMetadataLibrary.getType('JsName'),
        exportClass = jsMetadataLibrary.getType('Export'),
        noExportClass = jsMetadataLibrary.getType('NoExport'),
        jsifyClass = jsMetadataLibrary.getType('Jsify'),
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
    _removeNoSuchMethod(proxy);
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
          'new JsObject($JS_PREFIX.getPath("$jsConstructor"), '
              '[$parameterList]));');
    }
    return true;
  }

  void _removeNoSuchMethod(ClassElement proxy) {
    var nsm = proxy.methods.firstWhere((m) => m.name == 'noSuchMethod',
        orElse: () => null);
    if (nsm == null) return;
    var node = nsm.node;
    var body = node.body;
    if (body is ExpressionFunctionBody) {
      MethodInvocation m = body.expression;
      var paramName = node.parameters.parameterElements.single.name;
      if (m.realTarget is SuperExpression &&
          m.methodName.name == 'noSuchMethod') {
        var arg = m.argumentList.arguments.single;
        if (arg is SimpleIdentifier && arg.name == paramName) {
          var offset = node.offset;
          var end = node.end;
          transaction.edit(offset, end, '');
        }
      }
    }
    // TODO: log that we couldn't safely remove this noSuchMethod
  }

  void _generateAbstractMembers(ClassElement proxy) {
    var memberMap =
        inheritanceManager.getMapOfMembersInheritedFromInterfaces(proxy);

    for (var i = 0; i < memberMap.size; i++) {
      var memberKey = memberMap.getKey(i);
      var member = memberMap.getValue(i);

      var createSet = () => new Set<ClassElement>();
      if (generatedMembers.putIfAbsent(proxy, createSet).contains(member) ||
          (!member.isAbstract && !member.isSynthetic)) continue;
      generatedMembers[proxy].add(member);


      if (member is PropertyAccessorElement) {
        if (member.isGetter) {
          _generateGetter(proxy, member);
        } else if (member.isSetter) {
          _generateSetter(proxy, member);
        }
      } else if (member is MethodElement) {
        _generateMethod(proxy, member);
      }
    }
  }

  void _generateMethod(ClassElement proxy, MethodElement a) {
    var nameAnnotation = getNameAnnotation(a.node, jsNameClass);
    var name = nameAnnotation == null ? a.displayName : nameAnnotation.name;
    if (!a.isStatic) {
      var jsArgs = new List(a.parameters.length);

      for (int i = 0; i < a.parameters.length; i++) {
        var param = a.parameters[i];
        var hasJsify = hasAnnotation(param, jsifyClass);
        if (hasJsify) {
          jsArgs[i] = '$JS_PREFIX.jsify(${param.name})';
        } else {
          jsArgs[i] = '$JS_PREFIX.toJs(${param.name})';
        }
      }

      var parameterList = jsArgs.join(', ');

      var getContent = (DartType returnType, String name, String paramList) {
        var jsCall = "$JS_PREFIX.toJs(this).callMethod('$name', [$paramList])";
        return returnType.isVoid ? ' { $jsCall; }' :
            ' => $JS_PREFIX.toDart($jsCall, #${returnType.name})'
            ' as ${returnType};';
      };

      if (a.isSynthetic || a.enclosingElement != proxy) {
        var offset = proxy.node.end - 1;
        var source = a.node.toSource();
        source = source.substring(0, source.length - 1);
        transaction.edit(offset, offset,
            '  $source${getContent(a.returnType, name, parameterList)}\n');
      } else {
        MethodDeclaration m = a.node;
        var offset = m.body.offset;
        var end = m.body.end;
        transaction.edit(offset, end,
            getContent(a.returnType, name, parameterList));
      }
    }
  }

  void _generateSetter(ClassElement proxy, PropertyAccessorElement a) {
    var parameter = a.parameters.single;
    var type = parameter.type;
    if (type == null) {
      _logger.severe("abstract JsInterface setters must have type annotations");
      return;
    }

    var nameAnnotation = getNameAnnotation(a.isSynthetic ?
        a.variable.node.parent.parent : a.node, jsNameClass);
    var name = nameAnnotation != null ? nameAnnotation.name : a.displayName;

    var getContent = (String name, String parameterName) =>
        " { $JS_PREFIX.toJs(this)['$name'] = $JS_PREFIX.toJs($parameterName); }";

    var parameterName = parameter.name;
    if (a.isSynthetic || a.enclosingElement != proxy) {
      var offset = proxy.node.end - 1;
      transaction.edit(offset, offset,
          '  void set ${a.displayName}($type $parameterName)'
          '${getContent(name, parameterName)}\n');
    } else {
      MethodDeclaration m = a.node;
      var offset = m.body.offset;
      var end = m.body.end;
      transaction.edit(offset, end, getContent(name, parameterName));
    }
  }

  void _generateGetter(ClassElement proxy, PropertyAccessorElement a) {
    var type = a.type.returnType;
    if (type == null) {
      _logger.severe("abstract JsInterface getters must have type annotations");
      return;
    }

    var nameAnnotation = getNameAnnotation(a.isSynthetic ?
        a.variable.node.parent.parent : a.node, jsNameClass);
    var name = nameAnnotation != null ? nameAnnotation.name : a.displayName;

    var getContent = (String name, DartType type) =>
        " => $JS_PREFIX.toDart($JS_PREFIX.toJs(this)['$name']) as $type;";

    if (a.isSynthetic || a.enclosingElement != proxy) {
      var offset = proxy.node.end - 1;
      transaction.edit(offset, offset, "  ${a.returnType} get ${a.displayName}"
          "${getContent(name, a.returnType)}\n");
    } else {
      MethodDeclaration m = a.node;
      var offset = m.body.offset;
      var end = m.body.end;
      transaction.edit(offset, end, getContent(name, type));
    }
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
