// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.js_list;

import 'dart:collection';
import 'dart:js';

import 'package:js/js.dart';

/**
 * A [List] interface wrapper for [JsArray]s.
 *
 * Elements of this list are automatically converted to JavaScript with the
 * [toJs] function when added, and converted to Dart with the [toDart] funtion
 * when accessed.
 */
class JsList<E> extends ListBase<E> {
  JsArray _o;

  /**
   * Creates an instance backed by a new JavaScript Array.
   */
  JsList() : _o = new JsArray();

  /**
   * Creates an instance by deep converting [list] to JavaScript with [jsify].
   */
  JsList.jsify(List<E> list) : _o = jsify(list);

  /**
   * Creates an instance backed by the JavaScript object [o].
   */
  JsList.fromJsObject(JsObject o) : _o = o;

  @override
  int get length => _o.length;

  @override
  void set length(int length) { _o.length = length; }

  // TODO: add [E] as fallback type for toDart()
  @override
  E operator [](index) => toDart(_o[index]) as E;

  @override
  void operator []=(int index, E value) {
    _o[index] = toJs(value);
  }

  @override
  void add(E value) {
    _o.add(toJs(value));
  }

  @override
  void addAll(Iterable<E> iterable) {
    _o.addAll(iterable.map(toJs));
  }

  @override
  void sort([int compare(E a, E b)]) {
    final sortedList = toList()..sort(compare);
    setRange(0, sortedList.length, sortedList);
  }

  @override
  void insert(int index, E element) {
    _o.insert(index, toJs(element));
  }

  @override
  E removeAt(int index) {
    // TODO: add [E] as fallback type for toDart()
    return toDart(_o.removeAt(index)) as E;
  }

  // TODO: add [E] as fallback type for toDart()
  @override
  E removeLast() => toDart(_o.removeLast()) as E;

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int startFrom = 0]) {
    _o.setRange(start, end, iterable.map(toJs), startFrom);
  }

  @override
  void removeRange(int start, int end) {
    _o.removeRange(start, end);
  }
}
