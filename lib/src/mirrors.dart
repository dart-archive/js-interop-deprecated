// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains semi-private APIs for implementing typed interfaces and
 * exports.
 */
library js.mirrors;

import 'dart:js' as js;
import 'dart:mirrors';
import 'dart:mirrors' as mirrors;

import 'package:js/src/metadata.dart' as metadata;
import 'package:js/src/js_elements.dart';
import 'package:js/src/js_impl.dart' as jsi;
import 'package:js/src/js_impl.dart';

// This is the public interface of js.dart
// The exports must match those in static.dart
// JsInterface is not include to show the version defined here
export 'package:js/src/js_impl.dart' show JsGlobal, toJs, toDart,
    registerJsConstructorForType, registerFactoryForJsConstructor;
export 'dart:js' show JsObject;
export 'package:js/src/metadata.dart';

import 'package:quiver/mirrors.dart';

final _dart = js.context['dart'];
final _obj = js.context['Object'];

// This is ugly. For each ExportedClass we need a reference to the class mirror
// to implement constructors, but ExportedClass is used in code generation
// as well.
Expando<ClassMirror> _classMirrors = new Expando<ClassMirror>();

initializeJavaScript() {
  var libraries = currentMirrorSystem().libraries;

  var jsElements = new JsElements();
  var jsInterface = reflectType(JsInterface);

  for (var library in libraries.values) {
    var exportedLibrary;
    var libraryName = _getName(library);
    var libraryExportAnnotation = _getExportAnnotation(library);
    if (libraryExportAnnotation != null) {
      exportedLibrary = jsElements.getLibrary(libraryName);
    }

    var classes = library.declarations.values.where((d) => d is ClassMirror);
    for (ClassMirror clazz in classes) {
      metadata.JsProxy jsProxyAnnotation = _getJsProxyAnnotation(clazz);
      if (jsProxyAnnotation != null && jsProxyAnnotation.constructor != null) {
        _registerProxy(clazz, jsProxyAnnotation);
      }

      var classExportAnnotation = _getExportAnnotation(clazz);
      var classNoExportAnnotation = _getNoExportAnnotation(clazz);

      if (classNoExportAnnotation == null
          && !clazz.isAbstract
          && !classImplements(clazz, jsInterface)
          && (libraryExportAnnotation != null
              || classExportAnnotation != null)) {
        exportedLibrary = jsElements.getLibrary(libraryName);
        var name = _getName(clazz);
        var c = new ExportedClass(name, exportedLibrary);
        _classMirrors[c] = clazz;
        exportedLibrary.declarations[name] = c;
        _addExportedConstructors(clazz, c);
        _addExportedMembers(clazz, c);
      }
    }
  }

  for (ExportedLibrary library in jsElements.exportedLibraries.values) {
    _exportLibrary(library, _dart);
  }
}

void _addExportedMembers(ClassMirror clazz, ExportedClass c) {
  var declarations = getDeclarations(clazz);

  for (var declaration in declarations.values) {
    if (!declaration.isPrivate) {
      var name = _getName(declaration);
      var hasJsify = declaration.metadata
          .any((m) => m.reflectee == metadata.jsify);

      if (declaration is MethodMirror && !declaration.isOperator
          && name != 'noSuchMethod' && !declaration.isStatic) {
        if (declaration.isRegularMethod) {
          var parameters = declaration.parameters.map((p) =>
              new ExportedParameter(_getName(p), _getKind(p), _getType(p)))
              .toList();
          var method = new ExportedMethod(name, c, parameters,
              jsifyReturn: hasJsify);
          c.children[name] = method;
        } else if (declaration.isGetter) {
          ExportedProperty property = c.children[name];
          if (property == null) {
            c.children[name] = new ExportedProperty(name, c, hasGetter: true,
                jsify: hasJsify);
          } else {
            property.hasGetter = true;
            property.jsify = hasJsify;
          }
        } else if (declaration.isSetter) {
          // TODO: warn if hasJsify == true? It doesn't make sense on a setter.
          var propertyName = name.substring(0, name.length - 1);
          var property = c.children[propertyName];
          if (property == null) {
            c.children[propertyName] =
                new ExportedProperty(propertyName, c, hasSetter: true);
          } else {
            property.hasSetter = true;
          }
        }
      } else if (declaration is VariableMirror) {
        c.children[name] = new ExportedProperty(name, c,
            hasSetter: !declaration.isFinal,
            hasGetter: true,
            isStatic: declaration.isStatic,
            jsify: hasJsify);
      }
    }
  }
}

void _addExportedConstructors(ClassMirror clazz, ExportedClass c) {
  var constructors = clazz.declarations.values
      .where((d) => d is MethodMirror && d.isConstructor);
  for (MethodMirror ctor in constructors) {
    var rawName = _getName(ctor);
    // remove the class name
    var name = rawName == c.name ? '' : rawName.substring(c.name.length + 1);

    var parameters = ctor.parameters.map((p) =>
        new ExportedParameter(_getName(p), _getKind(p), _getType(p))).toList();

    c.children[name] = new ExportedConstructor(name, c, parameters);
  }
}

void _registerProxy(ClassMirror clazz, metadata.JsProxy jsProxyAnnotation) {
  var constructorExpr = jsProxyAnnotation.constructor;
  var createdConstructor = clazz.declarations[#created];
  jsi.registerFactoryForJsConstructor(
      getPath(jsProxyAnnotation.constructor),
      (JsObject o) => clazz.newInstance(#created, [o]).reflectee);
}

_exportLibrary(ExportedLibrary library, JsObject parent) {
  JsObject libraryJsObj = parent;
  var parts = library.name.split('.');
  parts.forEach((p) {
    if (!libraryJsObj.hasProperty(p)) {
      libraryJsObj = libraryJsObj[p] = new JsObject(_obj);
    } else {
      libraryJsObj = libraryJsObj[p];
    }
  });
  library.declarations.forEach((n, d) => _exportDeclaration(d, libraryJsObj));
}

_exportDeclaration(ExportedElement e, JsObject parent) {
  if (e is ExportedClass) {
    _exportClass(e, parent);
  }
}

_exportClass(ExportedClass c, JsObject parent) {
  var constructor;
  constructor = _convertCallback((self, args) {
    // The '_new' function is the no-named constructor, if one exists. It will
    // call the constructor and set the __dart_object__ property to the new
    // instance.
    constructor['_new'].apply(args, thisArg: self);
  });
  var prototype = _obj.callMethod('create', [_dart['Object']['prototype']]);
  constructor['prototype'] = prototype;
  constructor['prototype']['constructor'] = constructor;
  constructor['_wrapDartObject'] = (dartObject) {
    var o = _obj.callMethod('create', [constructor['prototype']]);
    o[DART_OBJECT_PROPERTY] = dartObject;
    return o;
  };
  parent[c.name] = constructor;
  var classMirror = _classMirrors[c];
  var type = classMirror.reflectedType;
  registerJsConstructorForType(type, constructor['_wrapDartObject']);

  c.children.forEach((n, d) => _exportClassMember(d, prototype, constructor));
}

_exportClassMember(ExportedElement e, JsObject prototype, JsObject ctor) {
  if (e is ExportedConstructor) {
    _exportConstructor(e, ctor);
  } else if (e is ExportedMethod) {
    _exportMethod(e, prototype);
  } else if (e is ExportedProperty) {
    _exportField(e, prototype);
  }
}

_exportConstructor(ExportedConstructor c, JsObject ctor) {
  var classMirror = _classMirrors[c.parent];
  var jsName = c.name == '' ? '_new' : c.name;
  var namedParameters = c.parameters
      .where((p) => p.kind == ParameterKind.NAMED).toList();
  var positionalParameterCount = c.parameters.length - namedParameters.length;
  ctor[jsName] = _convertCallback((self, args) {
    var positionalArgs = args;
    var namedArgs = <Symbol, dynamic>{};
    if (namedParameters.isNotEmpty &&
        args.length == positionalParameterCount + 1) {
      positionalArgs = args.sublist(0, positionalParameterCount);
      JsObject namedJsArgs = args[positionalParameterCount];
      for (var p in namedParameters) {
        if (namedJsArgs.hasProperty(p.name)) {
          namedArgs[new Symbol(p.name)] = namedJsArgs[p.name];
        }
      }
    }
    self[DART_OBJECT_PROPERTY] =
        classMirror.newInstance(new Symbol(c.name), positionalArgs, namedArgs)
            .reflectee;
  });
}

_exportMethod(ExportedMethod c, JsObject prototype) {
  var name = c.name;
  var namedParameters = c.parameters
      .where((p) => p.kind == ParameterKind.NAMED).toList();
  var positionalParameterCount = c.parameters.length - namedParameters.length;
  prototype[name] = _convertCallback((self, args) {
    var o = self[DART_OBJECT_PROPERTY];
    var positionalArgs = args;
    var namedArgs = null;

    if (namedParameters.isNotEmpty &&
        args.length == positionalParameterCount + 1) {
      positionalArgs = args.sublist(0, positionalParameterCount);
      JsObject namedJsArgs = args[positionalParameterCount];
      namedArgs = <Symbol, dynamic>{};
      for (var p in namedParameters) {
        if (namedJsArgs.hasProperty(p.name)) {
          namedArgs[new Symbol(p.name)] = namedJsArgs[p.name];
        }
      }
    }

    var result = reflect(o)
        .invoke(new Symbol(c.name), positionalArgs, namedArgs)
        .reflectee;

    if (c.jsifyReturn) {
      return jsify(result);
    }
    return result;
  });
}

_exportField(ExportedProperty e, JsObject prototype) {
  var accessors = {};
  if (e.hasGetter) {
    accessors['get'] = _convertCallback((self, args) {
      var o = self[DART_OBJECT_PROPERTY];
      var r = reflect(o).getField(new Symbol(e.name)).reflectee;
      if (e.jsify) r = jsify(r);
      return r;
    });
  }
  if (e.hasSetter) {
    accessors['set'] = _convertCallback((self, List args) {
      var o = self[DART_OBJECT_PROPERTY];
      var v = args.single;
      reflect(o).setField(new Symbol(e.name), v);
    });
  }
  _obj.callMethod('defineProperty', [prototype, e.name,
      new js.JsObject.jsify(accessors)]);
}

typedef JsCallback(receiver, List args);

js.JsFunction _convertCallback(JsCallback c) =>
    new js.JsFunction.withThis(new _CallbackFunction(c));

class _CallbackFunction implements Function {
  final JsCallback f;

  _CallbackFunction(this.f);

  call() => throw new StateError('There should always been at least 1 parameter'
      '(js this).');

  noSuchMethod(Invocation invocation) {
    var self = invocation.positionalArguments.first;
    var args = invocation.positionalArguments.skip(1).toList();
    return f(self, args);
  }
}

metadata.Export _getExportAnnotation(DeclarationMirror d) {
  var m = d.metadata
      .firstWhere((m) => m.type.reflectedType == metadata.Export,
          orElse: () => null);
  return m == null ? null : m.reflectee;
}

metadata.NoExport _getNoExportAnnotation(DeclarationMirror d) {
  var m = d.metadata
      .firstWhere((m) => m.type.reflectedType == metadata.NoExport,
          orElse: () => null);
  return m == null ? null : m.reflectee;
}

String _getName(DeclarationMirror m) => MirrorSystem.getName(m.simpleName);

ParameterKind _getKind(ParameterMirror p) {
  if (p.isNamed) return ParameterKind.NAMED;
  if (p.isOptional) return ParameterKind.POSITIONAL;
  return ParameterKind.REQUIRED;
}

DartType _getType(ParameterMirror p) => new DartType(_getName(p.type));

final Expando _globals = new Expando();

class JsInterface extends jsi.JsInterface {

  JsInterface.created(JsObject o) : super.created(o);

  factory JsInterface(Type type, Iterable args) {
    if (_globals[type] != null) {
      return _globals[type];
    }
    var classMirror = reflectClass(type);
    var jsProxyAnnotation = _getJsProxyAnnotation(classMirror);
    assert(jsProxyAnnotation != null);

    String jsConstructor = jsProxyAnnotation.constructor;
    var jsGlobal = jsProxyAnnotation.global;

    if (jsGlobal != true && jsConstructor == null) {
      throw new ArgumentError("JsProxies must have either be global or "
          "have a contructor: $type");
    }

    if (jsGlobal == true && jsConstructor != null) {
      throw new ArgumentError("JsProxies must not be both a global and "
          "have a constructor: $type global: '$jsGlobal'");
    }

    if (jsGlobal == true) {
      if (args != null && args.isNotEmpty) {
        throw new ArgumentError(
            "global JsProxies cannot have constuctor arguments");
      }
      var instance = classMirror.newInstance(#created, [jsi.context]).reflectee;
      _globals[type] = instance;
      return instance;
    }

    if (jsConstructor != null) {
      // TODO: support constructor expressions
      var ctor = getPath(jsConstructor);
      var jsObj = new JsObject(ctor, args);
      return classMirror.newInstance(#created, [jsObj]).reflectee;
    }
  }

  dynamic noSuchMethod(Invocation invocation) {
    var mirror = mirrors.reflect(this);
    var decl = getDeclaration(mirror.type, invocation.memberName);

    if (decl != null) {
      mirrors.MethodMirror method = decl;
      var nameAnnotation = _getJsNameAnnotation(method);
      var name = nameAnnotation != null ? nameAnnotation.name :
          mirrors.MirrorSystem.getName(invocation.memberName);
      if (invocation.isGetter) {
        var o = toDart(toJs(this)[name]);
        assert(o == null ||
            mirrors.reflect(o).type.isSubtypeOf(method.returnType));
        return o;
      }
      if (invocation.isSetter) {
        // remove the trailing '=' from the setter name
        name = name.substring(0, name.length - 1);
        var v = toJs(invocation.positionalArguments[0]);
        toJs(this)[name] = v;
        return null;
      }
      if (invocation.isMethod) {
        MethodMirror m = decl;
        var positionalParams = m.parameters.where((p) => !p.isNamed).toList();
        var positionalArgs = invocation.positionalArguments;
        var jsArgs = new List(positionalArgs.length);
        for (int i = 0; i < positionalArgs.length; i++) {
          var param = positionalParams[i];
          var arg = positionalArgs[i];
          var hasJsify = param.metadata
              .any((m) => m.reflectee == metadata.jsify);
          if (hasJsify) {
            jsArgs[i] = jsify(arg);
          } else {
            jsArgs[i] = toJs(arg);
          }
        }
        var returnType = m.returnType.hasReflectedType
            ? m.returnType.originalDeclaration.simpleName
            : null;
        var o = toDart(toJs(this).callMethod(name, jsArgs), returnType);
        assert(o == null ||
            mirrors.reflect(o).type.isSubtypeOf(method.returnType));
        return o;
      }
      assert(false);
    }
    return super.noSuchMethod(invocation);
  }
}

metadata.JsProxy _getJsProxyAnnotation(ClassMirror c) {
  var jsProxyAnnotationMirror = c.metadata
      .firstWhere((i) => i.reflectee is metadata.JsProxy, orElse: () => null);

  if (jsProxyAnnotationMirror == null) return null;

  return jsProxyAnnotationMirror.reflectee;
}

metadata.JsName _getJsNameAnnotation(MethodMirror m) {
  var jsNameAnnotationMirror =
      m.metadata
      .firstWhere((i) => i.reflectee is metadata.JsName, orElse: () => null);

  if (jsNameAnnotationMirror == null) return null;

  return jsNameAnnotationMirror.reflectee;
}


/**
 * Returns all the declarations on [classMirror] and its super classes and
 * interfaces. This is difference from [ClassMirror.instanceMembers].
 */
Map<Symbol, DeclarationMirror> getDeclarations(ClassMirror classMirror) {
  var declarations = new Map<Symbol, DeclarationMirror>();
  _getDeclarations(classMirror, declarations);
  return declarations;
}

_getDeclarations(ClassMirror classMirror,
                 Map<Symbol, DeclarationMirror> declarations) {
  for (ClassMirror superclass in classMirror.superinterfaces) {
    _getDeclarations(superclass, declarations);
  }
  if (classMirror.superclass != null) {
    _getDeclarations(classMirror.superclass, declarations);
  }
  // TODO: See if a getter can shadow an implicit setter from a field in a
  // superclass. This could happen if a superclass has a field and a subclass
  // has a getter with the same name. Since the field doesn't induce a setter
  // in the declarations, the field would be replaced by the getter and there
  // would be no associated setter. The solution would be to create a synthetic
  // setter if we're adding a getter than shadows a field.
  declarations.addAll(classMirror.declarations);
}
