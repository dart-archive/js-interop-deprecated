// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of js.wrapping;

/// Adapter to handle a js array as a dart [List].
/// You can provide a translator to automatically wrap contained Proxy to some
/// TypedProxy or something else.
class JsArrayToListAdapter<E> extends TypedProxy /*with ListMixin<E>*/ implements List<E> {

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
      : this._translator = translator,
        super.fromProxy(proxy);

  // Iterable
  @override Iterator<E> get iterator => new _JsIterator<E>(this);
  @override int get length => $unsafe.length;

  // Collection
  @override void add(E value) { $unsafe.push(_toJs(value)); }
  @override void clear() { this.length = 0; }
  @override bool remove(Object element) => removeAt(indexOf(element)) != null;

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
    $unsafe.splice(index, 0, _toJs(element));
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
  @override void removeRange(int start, int end) {
    $unsafe.splice(start, end - start);
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

  // ListMixin duplication until http://dartbug.com/9339 is fixed


  // Iterable interface.
//  Iterator<E> get iterator => new ListIterator<E>(this);

  E elementAt(int index) => this[index];

  void forEach(void action(E element)) {
    int length = this.length;
    for (int i = 0; i < length; i++) {
      action(this[i]);
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
  }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  E get first {
    if (length == 0) throw new StateError("No elements");
    return this[0];
  }

  E get last {
    if (length == 0) throw new StateError("No elements");
    return this[length - 1];
  }

  E get single {
    if (length == 0) throw new StateError("No elements");
    if (length > 1) throw new StateError("Too many elements");
    return this[0];
  }

  bool contains(E element) {
    int length = this.length;
    for (int i = 0; i < length; i++) {
      if (this[i] == element) return true;
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    return false;
  }

  bool every(bool test(E element)) {
    int length = this.length;
    for (int i = 0; i < length; i++) {
      if (!test(this[i])) return false;
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    return true;
  }

  bool any(bool test(E element)) {
    int length = this.length;
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return true;
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    return false;
  }

  E firstWhere(bool test(E element), { E orElse() }) {
    int length = this.length;
    for (int i = 0; i < length; i++) {
      E element = this[i];
      if (test(element)) return element;
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    if (orElse != null) return orElse();
    throw new StateError("No matching element");
  }

  E lastWhere(bool test(E element), { E orElse() }) {
    int length = this.length;
    for (int i = length - 1; i >= 0; i--) {
      E element = this[i];
      if (test(element)) return element;
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    if (orElse != null) return orElse();
    throw new StateError("No matching element");
  }

  E singleWhere(bool test(E element)) {
    int length = this.length;
    E match = null;
    bool matchFound = false;
    for (int i = 0; i < length; i++) {
      E element = this[i];
      if (test(element)) {
        if (matchFound) {
          throw new StateError("More than one matching element");
        }
        matchFound = true;
        match = element;
      }
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    if (matchFound) return match;
    throw new StateError("No matching element");
  }

  String join([String separator = ""]) {
    int length = this.length;
    if (!separator.isEmpty) {
      if (length == 0) return "";
      String first = "${this[0]}";
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
      StringBuffer buffer = new StringBuffer(first);
      for (int i = 1; i < length; i++) {
        buffer.write(separator);
        buffer.write(this[i]);
        if (length != this.length) {
          throw new ConcurrentModificationError(this);
        }
      }
      return buffer.toString();
    } else {
      StringBuffer buffer = new StringBuffer();
      for (int i = 0; i < length; i++) {
        buffer.write(this[i]);
        if (length != this.length) {
          throw new ConcurrentModificationError(this);
        }
      }
      return buffer.toString();
    }
  }

  Iterable<E> where(bool test(E element)) => _asList().where(test);

  Iterable map(f(E element)) => _asList().map(f);

  Iterable expand(Iterable f(E element)) => _asList().expand(f);

  E reduce(E combine(E previousValue, E element)) {
    if (length == 0) throw new StateError("No elements");
    E value = this[0];
    for (int i = 1; i < length; i++) {
      value = combine(value, this[i]);
    }
    return value;
  }

  fold(var initialValue, combine(var previousValue, E element)) {
    var value = initialValue;
    int length = this.length;
    for (int i = 0; i < length; i++) {
      value = combine(value, this[i]);
      if (length != this.length) {
        throw new ConcurrentModificationError(this);
      }
    }
    return value;
  }

  Iterable<E> skip(int count) => _asList().skip(count);

  Iterable<E> skipWhile(bool test(E element)) => _asList().skipWhile(test);

  Iterable<E> take(int count) => _asList().take(count);

  Iterable<E> takeWhile(bool test(E element)) => _asList().takeWhile(test);

  List<E> toList({ bool growable: true }) {
    List<E> result;
    if (growable) {
      result = new List<E>()..length = length;
    } else {
      result = new List<E>(length);
    }
    for (int i = 0; i < length; i++) {
      result[i] = this[i];
    }
    return result;
  }

  Set<E> toSet() {
    Set<E> result = new Set<E>();
    for (int i = 0; i < length; i++) {
      result.add(this[i]);
    }
    return result;
  }

  // Collection interface.
//  void add(E element) {
//    this[this.length++] = element;
//  }

  void addAll(Iterable<E> iterable) {
    for (E element in iterable) {
      this[this.length++] = element;
    }
  }

//  void remove(Object element) {
//    for (int i = 0; i < this.length; i++) {
//      if (this[i] == element) {
//        this.setRange(i, i + this.length - 1, this, i + 1);
//        this.length -= 1;
//        return;
//      }
//    }
//  }

  void removeWhere(bool test(E element)) {
    _filter(this, test, false);
  }

  void retainWhere(bool test(E element)) {
    _filter(this, test, true);
  }

  static void _filter(List source,
                      bool test(var element),
                      bool retainMatching) {
    List retained = [];
    int length = source.length;
    for (int i = 0; i < length; i++) {
      var element = source[i];
      if (test(element) == retainMatching) {
        retained.add(element);
      }
      if (length != source.length) {
        throw new ConcurrentModificationError(source);
      }
    }
    if (retained.length != source.length) {
      source.setRange(0, retained.length, retained);
      source.length = retained.length;
    }
  }

//  void clear() { this.length = 0; }

  // List interface.

//  E removeLast() {
//    if (length == 0) {
//      throw new StateError("No elements");
//    }
//    E result = this[length - 1];
//    length--;
//    return result;
//  }

//  void sort([Comparator<E> compare]) {
//    Sort.sort(this, compare);
//  }

  Map<int, E> asMap() => _asList().asMap();

  void _rangeCheck(int start, int end) {
    if (start < 0 || start > this.length) {
      throw new RangeError.range(start, 0, this.length);
    }
    if (end < start || end > this.length) {
      throw new RangeError.range(end, start, this.length);
    }
  }

//  List<E> sublist(int start, [int end]) {
//    if (end == null) end = length;
//    _rangeCheck(start, end);
//    int length = end - start;
//    List<E> result = new List<E>()..length = length;
//    for (int i = 0; i < length; i++) {
//      result[i] = this[start + i];
//    }
//    return result;
//  }

//  Iterable<E> getRange(int start, int end) {
//    _rangeCheck(start, end);
//    return new SubListIterable(this, start, end);
//  }

//  void removeRange(int start, int end) {
//    _rangeCheck(start, end);
//    int length = end - start;
//    setRange(start, this.length - length, this, end);
//    this.length -= length;
//  }

  void fillRange(int start, int end, [E fill]) {
    _rangeCheck(start, end);
    for (int i = start; i < end; i++) {
      this[i] = fill;
    }
  }

//  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
//    _rangeCheck(start, end);
//    int length = end - start;
//    if (length == 0) return;
//
//    if (skipCount < 0) throw new ArgumentError(skipCount);
//
//    List otherList;
//    int otherStart;
//    // TODO(floitsch): Make this accept more.
//    if (iterable is List) {
//      otherList = iterable;
//      otherStart = skipCount;
//    } else {
//      otherList = iterable.skip(skipCount).toList(growable: false);
//      otherStart = 0;
//    }
//    if (otherStart + length > otherList.length) {
//      throw new StateError("Not enough elements");
//    }
//    if (otherStart < start) {
//      // Copy backwards to ensure correct copy if [from] is this.
//      for (int i = length - 1; i >= 0; i--) {
//        this[start + i] = otherList[otherStart + i];
//      }
//    } else {
//      for (int i = 0; i < length; i++) {
//        this[start + i] = otherList[otherStart + i];
//      }
//    }
//  }

  void replaceRange(int start, int end, Iterable<E> newContents) {
    // TODO(floitsch): Optimize this.
    removeRange(start, end);
    insertAll(start, newContents);
  }

  int indexOf(E element, [int startIndex = 0]) {
    if (startIndex >= this.length) {
      return -1;
    }
    if (startIndex < 0) {
      startIndex = 0;
    }
    for (int i = startIndex; i < this.length; i++) {
      if (this[i] == element) {
        return i;
      }
    }
    return -1;
  }

  /**
   * Returns the last index in the list [a] of the given [element], starting
   * the search at index [startIndex] to 0.
   * Returns -1 if [element] is not found.
   */
  int lastIndexOf(E element, [int startIndex]) {
    if (startIndex == null) {
      startIndex = this.length - 1;
    } else {
      if (startIndex < 0) {
        return -1;
      }
      if (startIndex >= this.length) {
        startIndex = this.length - 1;
      }
    }
    for (int i = startIndex; i >= 0; i--) {
      if (this[i] == element) {
        return i;
      }
    }
    return -1;
  }

//  void insert(int index, E element) {
//    if (index < 0 || index > length) {
//      throw new RangeError.range(index, 0, length);
//    }
//    if (index == this.length) {
//      add(element);
//      return;
//    }
//    // We are modifying the length just below the is-check. Without the check
//    // Array.copy could throw an exception, leaving the list in a bad state
//    // (with a length that has been increased, but without a new element).
//    if (index is! int) throw new ArgumentError(index);
//    this.length++;
//    setRange(index + 1, this.length, this, index);
//    this[index] = element;
//  }

//  E removeAt(int index) {
//    E result = this[index];
//    setRange(index, this.length - 1, this, index + 1);
//    length--;
//    return result;
//  }

  void insertAll(int index, Iterable<E> iterable) {
    if (index < 0 || index > length) {
      throw new RangeError.range(index, 0, length);
    }
    // TODO(floitsch): we can probably detect more cases.
    if (iterable is! List && iterable is! Set /*&& iterable is! SubListIterable*/) {
      iterable = iterable.toList();
    }
    int insertionLength = iterable.length;
    // There might be errors after the length change, in which case the list
    // will end up being modified but the operation not complete. Unless we
    // always go through a "toList" we can't really avoid that.
    this.length += insertionLength;
    setRange(index + insertionLength, this.length, this, index);
    setAll(index, iterable);
  }

  void setAll(int index, Iterable<E> iterable) {
    if (iterable is List) {
      setRange(index, index + iterable.length, iterable);
    } else {
      for (E element in iterable) {
        this[index++] = element;
      }
    }
  }

  Iterable<E> get reversed => _asList().reversed;

  String toString() => _asList().toString();
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
