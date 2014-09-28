@Export()
library test.library2;

import 'package:js/js.dart';


abstract class Library2 extends JsInterface {
  factory Library2() => new Library2Impl();
  Library2.created(JsObject o) : super.created(o);

  DartOnly createDartOnly();

  Gizmo createGizmo(String x);

  JsAndDart createJsAndDart(int i);
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
