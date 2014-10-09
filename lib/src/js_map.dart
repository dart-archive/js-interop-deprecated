// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.js_object_map;

import 'dart:collection' show Maps, MapMixin;
import 'dart:js';

import 'package:js/src/js_impl.dart';

/**
 * A [Map] interface wrapper for [JsObject]s.
 *
 * Values returned from this map are automatically converted to JavaScript with
 * the [toJs] function when added, and to Dart with the [toDart] funtion when
 * accessed.
 *
 * Keys must be [String] because they are used as JavaScript property names. The
 * key '__proto__' is disallowed.
 */
class JsMap<V> extends MapMixin<String, V> {
  static final _obj = context['Object'];

  final JsObject _o;

  /**
   * Creates an instance backed by a new JavaScript object whose prototype is
   * Object.
   */
  JsMap() : _o = new JsObject(_obj);

  /**
   * Creates an instance by deep converting [map] to JavaScript with [jsify].
   */
  JsMap.jsify(Map<String, dynamic> map) : _o = jsify(map);

  /**
   * Creates an instance backed by the JavaScript object [o].
   */
  JsMap.fromJsObject(JsObject o) : _o = o;

  void _checkKey(String key) {
    if (key == '__proto__') {
      throw new ArgumentError("'__proto__' is disallowed as a key");
    }
  }

  @override
  V operator [](String key) => toDart(_o[key]) as V;

  @override
  void operator []=(String key, V value) {
    _checkKey(key);
    _o[key] = toJs(value);
  }

  @override
  V remove(String key) {
    final value = this[key];
    _o.deleteProperty(key);
    return value as V;
  }

  @override
  Iterable<String> get keys => _obj.callMethod('keys', [_o]) as List<String>;

  @override
  bool containsKey(String key) => _o.hasProperty(key);

  @override
  V putIfAbsent(String key, V ifAbsent()) {
    _checkKey(key);
    return Maps.putIfAbsent(this, key, ifAbsent) as V;
  }

  @override
  void addAll(Map<String, V> other) {
    if (other != null) {
      other.forEach((k,v) => this[k] = v);
    }
  }

  @override
  void clear() => Maps.clear(this);
}
