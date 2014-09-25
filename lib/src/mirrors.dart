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

import 'package:js/src/metadata.dart';
import 'package:js/src/js_elements.dart';
import 'package:js/src/js_impl.dart' as jsi;
import 'package:js/src/js_impl.dart';

// This is the public interface of js.dart
// The exports must match those in static.dart
export 'package:js/src/js_impl.dart' hide JsInterface;
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
      JsProxy jsProxyAnnotation = _getJsProxyAnnotation(clazz);
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

  for (var m in declarations.values) {
    if (!m.isPrivate) {
      var name = _getName(m);

      if (m is MethodMirror) {
        if (m.isRegularMethod) {
          var parameters = m.parameters.map((p) =>
              new ExportedParameter(_getName(p), _getKind(p), _getType(p)));
          var method = new ExportedMethod(name, c, parameters);
          c.children[name] = method;
        } else if (m.isGetter) {
          var property = c.children[name];
          if (property == null) {
            c.children[name] = new ExportedProperty(name, c, hasGetter: true);
          } else {
            property.hasGetter = true;
          }
        } else if (m.isSetter) {
          var propertyName = name.substring(0, name.length - 1);
          var property = c.children[propertyName];
          if (property == null) {
            c.children[propertyName] =
                new ExportedProperty(propertyName, c, hasSetter: true);
          } else {
            property.hasSetter = true;
          }
        }
      } else if (m is VariableMirror) {
        c.children[name] = new ExportedProperty(name, c,
            hasSetter: !m.isFinal,
            hasGetter: true,
            isStatic: m.isStatic);
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
        new ExportedParameter(_getName(p), _getKind(p), _getType(p)));

    c.children[name] = new ExportedConstructor(name, c, parameters);
  }
}

void _registerProxy(ClassMirror clazz, JsProxy jsProxyAnnotation) {
  var constructorExpr = jsProxyAnnotation.constructor;
  var createdConstructor = clazz.declarations[#created];
  jsi.registerFactoryForJsConstructor(
      jsi.context[jsProxyAnnotation.constructor],
      (JsObject o) => clazz.newInstance(#created, [o]).reflectee);
}

_exportLibrary(ExportedLibrary library, JsObject parent) {
  print("exporting library ${library.name}");
  JsObject libraryJsObj = parent;
  var parts = library.name.split('.');
  parts.forEach((p) {
    if (!libraryJsObj.hasProperty(p)) {
      libraryJsObj = libraryJsObj[p] = new JsObject.jsify({});
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
  constructor = new js.JsFunction.withThis((self) {
    self['__dart_object__'] = constructor.callMethod('_new');
  });
  var prototype = _obj.callMethod('create', [_dart['Object']['prototype']]);
  constructor['prototype'] = prototype;
  constructor['prototype']['constructor'] = constructor;
  constructor['_wrapDartObject'] = (dartObject) {
    var o = _obj.callMethod('create', [constructor['prototype']]);
    o['__dart_object__'] = dartObject;
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
  if (c.name == '') {
    ctor['_new'] =
        () => classMirror.newInstance(new Symbol(c.name), []).reflectee;
  } else {
    var jsParams = c.parameters.map((p) => p.name).toList();
    ctor[c.name] = _convertCallback((self, args) {
      self['__dart_object__'] =
          classMirror.newInstance(new Symbol(c.name), args).reflectee;
    });
  }
}

_exportMethod(ExportedMethod c, JsObject prototype) {
  var name = c.name;
  var classMirror = _classMirrors[c.parent];
  prototype[name] = new js.JsFunction.withThis((self) {
    var o = self['__dart_object__'];
    return reflect(o).invoke(new Symbol(c.name), []).reflectee;
  });
}

_exportField(ExportedProperty e, JsObject prototype) {
  _obj.callMethod('defineProperty', [prototype, e.name,
    new js.JsObject.jsify({
      'get': _convertCallback((self, args) {
        var o = self['__dart_object__'];
        var r = reflect(o).getField(new Symbol(e.name)).reflectee;
        return r;
      }),
      'set': _convertCallback((self, List args) {
        var o = self['__dart_object__'];
        var v = args.single;
        reflect(o).setField(new Symbol(e.name), v);
      })
    })
  ]);
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

Export _getExportAnnotation(DeclarationMirror d) {
  var m = d.metadata.firstWhere((m) => m.type.reflectedType == Export,
      orElse: () => null);
  return m == null ? null : m.reflectee;
}

NoExport _getNoExportAnnotation(DeclarationMirror d) {
  var m = d.metadata.firstWhere((m) => m.type.reflectedType == NoExport,
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
      var ctor = jsi.context[jsConstructor];
      var jsObj = new JsObject(ctor, args);
      return classMirror.newInstance(#created, [jsObj]).reflectee;
    }
  }

  dynamic noSuchMethod(Invocation i) {
    var mirror = mirrors.reflect(this);
    var decl = getDeclaration(mirror.type, i.memberName);

    if (decl != null) {
      mirrors.MethodMirror method = decl;
      String name = mirrors.MirrorSystem.getName(i.memberName);
      if (i.isGetter) {
        var o = toDart(toJs(this)[name]);
        assert(o == null ||
            mirrors.reflect(o).type.isSubtypeOf(method.returnType));
        return o;
      }
      if (i.isSetter) {
        // remove the trailing '=' from the setter name
        name = name.substring(0, name.length - 1);
        var v = toJs(i.positionalArguments[0]);
        toJs(this)[name] = v;
        return null;
      }
      if (i.isMethod) {
        var jsArgs = i.positionalArguments.map(toJs).toList();
        var o = toDart(toJs(this).callMethod(name, jsArgs));
        assert(o == null ||
            mirrors.reflect(o).type.isSubtypeOf(method.returnType));
        return o;
      }
      assert(false);
    }
    return super.noSuchMethod(i);
  }
}

JsProxy _getJsProxyAnnotation(ClassMirror c) {
  var jsProxyAnnotationMirror =
      c.metadata
      .firstWhere((i) => i.reflectee is JsProxy, orElse: () => null);

  if (jsProxyAnnotationMirror == null) return null;

  return jsProxyAnnotationMirror.reflectee;
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