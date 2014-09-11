// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains semi-private APIs for implementing typed interfaces and
 * exports.
 */
library js.mirrors;

import 'package:js/src/metadata.dart';
import 'package:js/src/js_impl.dart' as jsi;
import 'package:js/src/js_impl.dart';
import 'package:js/js.dart';
import 'package:quiver/mirrors.dart';

import 'dart:mirrors';
import 'dart:mirrors' as mirrors;

initializeJavaScript() {
  var libraries = currentMirrorSystem().libraries;
  for (var library in libraries.values) {
    var classes = library.declarations.values.where((d) => d is ClassMirror);
    for (ClassMirror clazz in classes) {

      JsProxy jsProxyAnnotation = _getJsProxyAnnotation(clazz);
      if (jsProxyAnnotation == null) continue;

      if (jsProxyAnnotation.constructor != null) {
        var constructorExpr = jsProxyAnnotation.constructor;
        var createdConstructor = clazz.declarations[#created];
        jsi.registerFactoryForJsConstructor(
            jsi.context[jsProxyAnnotation.constructor],
            (JsObject o) => clazz.newInstance(#created, [o]).reflectee);
      }
    }
  }
}

final Expando _globals = new Expando();

class JsInterfaceImpl {

  JsInterfaceImpl.created();

  factory JsInterfaceImpl(Type type, Iterable args) {
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
        print("calling method: $name");
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
