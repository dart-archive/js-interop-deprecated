// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.wrapping;

/// Adapter to handle a js array as a dart [List].
/// You can provide a translator to automatically wrap contained Proxy to some
/// TypedProxy or something else.
class JsArrayToListAdapter<E> extends TypedProxy implements List<E> {

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
  JsArrayToListAdapter.fromProxy(Proxy proxy, [Translator<E> translator]) :
      super.fromProxy(proxy), this._translator = translator;

  // Iterable
  @override Iterator<E> get iterator => new _JsIterator<E>(this);
  @override int get length => $unsafe.length;

  // Collection
  @override void add(E value) { $unsafe.push(_toJs(value)); }
  @override void clear() { this.length = 0; }
  @override void remove(Object element) { removeAt(indexOf(element)); }

  // List
  @override E operator [](int index) {
    if (index < 0 || index >= this.length) throw new RangeError.value(index);
    return _fromJs($unsafe[index]);
  }
  @override void operator []=(int index, E value) {
    if (index < 0 || index >= this.length) throw new RangeError.value(index);
    $unsafe[index] = _toJs(value);
  }
  @override void set length(int length) { $unsafe.length = length; }
  @override void sort([int compare(E a, E b)]) {
    final sortedList = _asList()..sort(compare);
    setRange(0, sortedList.length, sortedList);
  }
  @override void insert(int index, E element) {
    this.insertRange(index, 1, element);
  }
  @override E removeAt(int index) {
    if (index < 0 || index >= this.length) throw new RangeError.value(index);
    return _fromJs($unsafe.splice(index, 1)[0]);
  }
  @override E removeLast() => _fromJs($unsafe.pop());
  @override List<E> sublist(int start, [int end]) =>
      _asList().sublist(start, end);
  @deprecated @override List<E> getRange(int start, int length) =>
      _asList().getRange(start, length);
  @override void setRange(int start, int length, List<E> from,
                          [int startFrom = 0]) {
    final args = [start, length];
    for(int i = startFrom; i < startFrom + length; i++) {
      args.add(_toJs(from[i]));
    }
    $unsafe["splice"].apply($unsafe, array(args));
  }
  @override void removeRange(int start, int length) {
    $unsafe.splice(start, length);
  }
  @override void insertRange(int start, int length, [E initialValue]) {
    final args = [start, 0];
    for (int i = 0; i < length; i++) {
      args.add(_toJs(initialValue));
    }
    $unsafe["splice"].apply($unsafe, array(args));
  }

  // private methods
  dynamic _toJs(E e) => _translator == null ? e : _translator.toJs(e);
  E _fromJs(dynamic value) => _translator == null ? value :
      _translator.fromJs(value);

  List<E> _asList() {
    final list = new List<E>();
    for (int i = 0; i < length; i++) {
      list.add(this[i]);
    }
    return list;
  }

  // default implementation for most method
  // TODO : waiting for mixins
  @override Iterable map(f(E element)) =>
      IterableMixinWorkaround.mapList(this, f);
  @override Iterable<E> where(bool f(E element)) =>
      IterableMixinWorkaround.where(this, f);
  @override Iterable expand(Iterable f(E element)) =>
      IterableMixinWorkaround.expand(this, f);
  @override bool contains(E element) =>
      IterableMixinWorkaround.contains(this, element);
  @override void forEach(void f(E element)) =>
      IterableMixinWorkaround.forEach(this, f);
  @override dynamic reduce(var initialValue,
                           dynamic combine(var previousValue, E element)) =>
      IterableMixinWorkaround.reduce(this, initialValue, combine);
  @override bool every(bool f(E element)) =>
      IterableMixinWorkaround.every(this, f);
  @override String join([String separator]) =>
      IterableMixinWorkaround.join(this, separator);
  @override bool any(bool f(E element)) => IterableMixinWorkaround.any(this, f);
  @override List<E> toList({ bool growable: true }) =>
      new List<E>.from(this, growable: growable);
  @override Set<E> toSet() => new Set<E>.from(this);
  @override E min([int compare(E a, E b)]) =>
      IterableMixinWorkaround.min(this, compare);
  @override E max([int compare(E a, E b)]) =>
      IterableMixinWorkaround.max(this, compare);
  @override bool get isEmpty => IterableMixinWorkaround.isEmpty(this);
  @override Iterable<E> take(int n) =>
      IterableMixinWorkaround.takeList(this, n);
  @override Iterable<E> takeWhile(bool test(E value)) =>
      IterableMixinWorkaround.takeWhile(this, test);
  @override Iterable<E> skip(int n) =>
      IterableMixinWorkaround.skipList(this, n);
  @override Iterable<E> skipWhile(bool test(E value)) =>
      IterableMixinWorkaround.skipWhile(this, test);
  @override E get first => IterableMixinWorkaround.first(this);
  @override E get last => IterableMixinWorkaround.last(this);
  @override E get single => IterableMixinWorkaround.single(this);
  @override E firstWhere(bool test(E value), { E orElse() }) =>
      IterableMixinWorkaround.firstWhere(this, test, orElse);
  @override E lastWhere(bool test(E value), {E orElse()}) =>
      IterableMixinWorkaround.lastWhere(this, test, orElse);
  @override E singleWhere(bool test(E value)) =>
      IterableMixinWorkaround.singleWhere(this, test);
  @override E elementAt(int index) =>
      IterableMixinWorkaround.elementAt(this, index);

  // Collection
  @override void addAll(Iterable<E> elements) {
    for (E element in elements) {
      add(element);
    }
  }
  @override void removeAll(Iterable elements) =>
      IterableMixinWorkaround.removeAll(this, elements);
  @override void retainAll(Iterable elements) =>
      IterableMixinWorkaround.retainAll(this, elements);
  @override void removeWhere(bool test(E element)) =>
      IterableMixinWorkaround.removeWhere(this, test);
  @override void retainWhere(bool test(E element)) =>
      IterableMixinWorkaround.retainWhere(this, test);

  // List
  @deprecated @override void addLast(E value) { add(value); }
  @override Iterable<E> get reversed =>
      IterableMixinWorkaround.reversedList(this);
  @override int indexOf(E element, [int start = 0]) =>
      IterableMixinWorkaround.indexOfList(this, element, start);
  @override int lastIndexOf(E element, [int start]) =>
      IterableMixinWorkaround.lastIndexOfList(this, element, start);
  @override Map<int, E> asMap() => IterableMixinWorkaround.asMapList(this);
}

class _JsIterator<E> implements Iterator<E> {
  final JsArrayToListAdapter<E> _jsArray;
  final int length;
  int _currentIndex = -1;

  _JsIterator(JsArrayToListAdapter<E> jsArray) : this._jsArray = jsArray,
      length = jsArray.length;

  // Iterator
  @override bool moveNext() {
    if (_currentIndex + 1 < length) {
      _currentIndex++;
      return true;
    }
    return false;
  }
  @override E get current => _jsArray[_currentIndex];
}
