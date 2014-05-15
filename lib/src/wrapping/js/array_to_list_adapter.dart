// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.wrapping;

/// Adapter to handle a js array as a dart [List].
/// You can provide a translator to automatically wrap contained Proxy to some
/// TypedProxy or something else.
class JsArrayToListAdapter<E> extends TypedProxy with ListMixin<E> {

  /// Like [JsArrayToListAdapter.fromProxy] but with `null` handling for
  /// [proxy].
  static JsArrayToListAdapter cast(Proxy proxy, [Translator translator]) =>
      proxy == null ? null :
          new JsArrayToListAdapter.fromProxy(proxy, translator);

  /// Same as [cast] but for array containing [Serializable] elements.
  static JsArrayToListAdapter castListOfSerializables(Proxy proxy,
      Mapper<dynamic, Serializable> fromJs, {mapOnlyNotNull: false}) =>
          proxy == null ? null : new JsArrayToListAdapter.fromProxy(proxy,
              new TranslatorForSerializable(fromJs,
                  mapOnlyNotNull: mapOnlyNotNull));

  final Translator<E> _translator;

  /// Create a new adapter from a proxy of a Js list.
  JsArrayToListAdapter.fromProxy(Proxy proxy, [Translator<E> translator])
      : _translator = translator,
        super.fromProxy(proxy);

  // private methods
  dynamic _toJs(E e) => _translator == null ? e : _translator.toJs(e);
  E _fromJs(dynamic value) => _translator == null ? value :
      _translator.fromJs(value);

  // method to implement for ListMixin

  @override int get length => $unsafe['length'];
  @override void set length(int length) { $unsafe['length'] = length; }
  @override E operator [](index) => _fromJs($unsafe[index]);
  @override void operator []=(index, E value) {
    $unsafe[index] = _toJs(value);
  }

  // overriden methods for better performance
  @override void insert(int index, E element) {
    $unsafe['splice'].apply($unsafe, array([index, 0, _toJs(element)]));
  }
  @override void setRange(int start, int end, Iterable<E> iterable,
                          [int skipCount = 0]) {
    final args = [start, end - start]
      ..addAll(iterable.skip(skipCount).map(_toJs));
    $unsafe['splice'].apply($unsafe, array(args));
  }
  @override void sort([int compare(E a, E b)]) {
    final sortedList = toList()..sort(compare);
    setRange(0, sortedList.length, sortedList);
  }
}
