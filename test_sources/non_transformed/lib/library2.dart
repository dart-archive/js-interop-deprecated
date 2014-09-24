@Export()
library test.library2;

import 'package:js/js.dart';


abstract class Library2 extends JsInterface {
  factory Library2() => new Library2Impl();
  Library2.created(JsObject o) : super.created(o);

  DartOnly createDartOnly();
}

@JsProxy(global: true)
class Library2Impl extends Library2 {
  factory Library2Impl() => new JsInterface(Library2Impl, []);
  Library2Impl.created(JsObject o) : super.created(o);
  noSuchMethod(i) => super.noSuchMethod(i);
}

@NoExport()
class DartOnly {}

@Export()
class JsAndDart {}

