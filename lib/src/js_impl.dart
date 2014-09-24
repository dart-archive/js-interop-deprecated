// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains semi-private APIs for implementing typed interfaces and
 * exports.
 */
library js.impl;

import 'dart:js';
export 'dart:js' show context, JsObject;

// TODO(justinfagnani): replace this import with a static impl
// during transformation
import 'package:js/src/mirrors.dart';
import 'package:js/src/mirrors.dart' as mirrors show isGlobal;

const DART_OBJECT_PROPERTY = '__dart_object__';

/**
 * The base class of Dart interfaces for JavaScript objects.
 */
abstract class JsInterface extends JsInterfaceImpl {

  final JsObject _jsObject;

  factory JsInterface(Type type, [Iterable args]) =>
      new JsInterfaceImpl(type, args);

  JsInterface.created(JsObject o) : _jsObject = o, super.created() {
    // since multiple Dart objects of different classes may represent
    // the global name space, we don't store a reference
    if (!isGlobal(this)) {
      if (o[DART_OBJECT_PROPERTY] != null) {
        throw new ArgumentError('JsObject is already wrapped');
      }
      o[DART_OBJECT_PROPERTY] = this;
    }
  }

}

// This only works in JS because we're still pulling mirrors. We need to
// generate metadata about which classes are global when we transform out
// mirrors.
bool isGlobal(JsInterface o) => mirrors.isGlobal(o);

/**
 * Converts a Dart object to a [JsObject] (or supported primitive) for sending
 * to JavaScript. [o] must be either a [JsInterface] or an exported Dart object.
 */
dynamic toJs(dynamic o) {
  if (o == null) return o;
  if (o is num || o is String || o is bool) return o;

  if (o is JsInterface) return  o._jsObject;
  var type = o.runtimeType;
  var ctor = _exportedConstructors[type];
  if (ctor != null) {
    var proxy = _exportedProxies[o];
    if (proxy == null) {
      proxy = new JsObject(ctor, [o]);
      _exportedProxies[o] = proxy;
    }
    return proxy;
  }
  // TODO: check that `o` is transferrable?
  return o;
}

// Exported Dart Object -> JsObject
final Expando<JsObject> _exportedProxies = new Expando<JsObject>();

dynamic toDart(dynamic o) {
  if (o == null) return o;
  if (o is num || o is String || o is bool) return o;

  var wrapper = o[DART_OBJECT_PROPERTY];
  if (wrapper == null) {
    // look up JsInterface factory
    var jsConstructor = o['constructor'] as JsObject;
    var dartConstructor = _interfaceConstructors[jsConstructor];
    if (dartConstructor == null) {
      throw new ArgumentError("Could not convert $o to Dart");
    }
    wrapper = dartConstructor(o);
    o[DART_OBJECT_PROPERTY] = wrapper;
  }
  return wrapper;
}

// Dart Type -> JS constructorfor proxy
final Map<Type, JsObject> _exportedConstructors = <Type, JsObject>{};

registerJsConstructorForType(Type type, JsObject constructor) {
  _exportedConstructors[type] = constructor;
}

// Dart Type -> JS constructorfor proxy
final Map<JsFunction, InterfaceFactory> _interfaceConstructors =
    <JsFunction, InterfaceFactory>{};

typedef JsInterface InterfaceFactory(JsObject o);

registerFactoryForJsConstructor(JsObject constructor,
    InterfaceFactory factory) {
  _interfaceConstructors[constructor] = factory;
}
