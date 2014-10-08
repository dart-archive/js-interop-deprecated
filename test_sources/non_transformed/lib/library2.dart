@Export()
library test.library2;

import 'package:js/js.dart';


abstract class Library2 extends JsInterface {
  factory Library2() => new Library2Impl();
  Library2.created(JsObject o) : super.created(o);

  DartOnly createDartOnly();

  Gizmo createGizmo(String x);

  JsAndDart createJsAndDart(int i);

  List createList(a, b, c);

  String joinList(@jsify List list);

  // The returned object is only a transient wrapper on the underlying JS
  // object. We might want to make this clear by requiring metadata like
  // @JsMap. We also might want to support @dartify which would do a deep
  // copy+convert from JS to Dart
  Map<String, int> createMap(k1, v1, k2, v2);

  String joinMap(@jsify Map<String, int> map);

  List callCreateList(JsAndDart o);

  List callListGetter(JsAndDart o);

  List callListField(JsAndDart o);

}

@JsProxy(global: true)
class Library2Impl extends Library2 implements JsGlobal {
  factory Library2Impl() => new JsInterface(Library2Impl, []);
  Library2Impl.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}

@NoExport()
class DartOnly {}

@Export()
class JsAndDart {
  final int i;
  JsAndDart(this.i);

  @jsify
  List createList(a, b, c) => [a, b, c];

  @jsify
  Map createMap(k1, v1, k2, v2) => {k1: v1, k2: v2};

  @jsify
  List get listGetter => [1, 2, 3];

  @jsify
  List listField = [8, 3, 1];
}

abstract class Gizmo extends JsInterface {
  factory Gizmo(String x) => new GizmoImpl(x);
  Gizmo.created(JsObject o) : super.created(o);

  String get x;
  void set x(String x);
}

@JsProxy(constructor: 'namespace.Gizmo')
class GizmoImpl extends Gizmo {
  factory GizmoImpl(String x) => new JsInterface(GizmoImpl, [x]);
  GizmoImpl.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}
