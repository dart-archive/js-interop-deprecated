// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains semi-private APIs for implementing typed interfaces and
 * exports.
 */
library js.impl;

import 'dart:js';
import 'package:js/src/js_map.dart';
import 'package:js/src/js_list.dart';
import 'dart:collection';
export 'dart:js' show context, JsObject;

const DART_OBJECT_PROPERTY = '__dart_object__';

/**
 * The base class of Dart interfaces for JavaScript objects.
 */
abstract class JsInterface {

  final JsObject _jsObject;

  factory JsInterface(Type type, [Iterable args]) {
    throw new StateError('JsInterface should never be called');
  }

  JsInterface.created(JsObject o) : _jsObject = o {
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

/**
 * Marker interface for global objects.
 */
abstract class JsGlobal {}

bool isGlobal(JsInterface o) => o is JsGlobal;

/**
 * Converts a Dart object to a [JsObject] (or supported primitive) for sending
 * to JavaScript. [o] must be either a [JsInterface] or an exported Dart object.
 */
dynamic toJs(dynamic o) {
  if (o == null) return o;
  if (o is num || o is String || o is bool || o is DateTime
      || o is JsObject) return o;

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

/**
 * Converts a JS value (primitive or [JsObject]) to Dart.
 *
 * If [o] is a JS object with a associated Dart proxy class, an instance of that
 * proxy class is returned. If [o] is an exported Dart object, the original
 * Dart object is returned. The Dart object is stored as a reference on the
 * JS object so that the same Dart object is returned from subsequent calls
 * to [toDart].
 *
 * If [o] is a JS object with no associated proxy class, the [fallbackType] is
 * used to create a transient wrapper of the correct type. Currently [Map] is
 * the only supported fallback type. [Future] and [Stream] are planned fallback
 * types.
 */
dynamic toDart(dynamic o, [Symbol fallbackType]) {
  if (o == null) return o;
  if (o is num || o is String || o is bool || o is DateTime) return o;

  if (o is JsObject) {
    var wrapper = o[DART_OBJECT_PROPERTY];
    if (wrapper == null) {
      if (o is JsArray) {
        wrapper = new JsList.fromJsObject(o);
      } else {
        // look up JsInterface factory
        var jsConstructor = o['constructor'] as JsObject;
        var dartConstructor = _interfaceConstructors[jsConstructor];
        if (dartConstructor != null) {
          wrapper = dartConstructor(o);
        }
      }
      if (wrapper != null) {
        o[DART_OBJECT_PROPERTY] = wrapper;
      }
    }
    if (wrapper != null) return wrapper;

    // no wrapper, handle fallback cases
    if (fallbackType == #Map) {
      return new JsMap.fromJsObject(o);
    }

    return o;
  }
  throw new ArgumentError("Could not convert ${o.runtimeType}($o) to Dart");
}

JsObject _obj = context['Object'];

dynamic jsify(data) {
  if ((data is! Map) && (data is! Iterable)) {
    throw new ArgumentError("object must be a Map or Iterable, was $data");
  }

  if (data is JsObject || data is JsMap || data is JsList) return data;

  var _convertedObjects = new HashMap.identity();

  _convert(o) {
    if (_convertedObjects.containsKey(o)) {
      return _convertedObjects[o];
    }
    if (o is Map) {
      final convertedMap = new JsObject(_obj);
      _convertedObjects[o] = convertedMap;
      for (var key in o.keys) {
        convertedMap[key] = _convert(o[key]);
      }
      return convertedMap;
    } else if (o is Iterable) {
      var convertedList = new JsArray();
      _convertedObjects[o] = convertedList;
      convertedList.addAll(o.map(_convert));
      return convertedList;
    } else {
      return toJs(o);
    }
  }

  return _convert(data);
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

dynamic getOptionalArg(JsObject args, String name) {
  if (args == null) return null;
  return args[name];
}

JsObject getPath(String path) =>
    path.split('.').fold(context, (JsObject o, p) => o[p]);
