library js.transformer_test;

import 'package:js/js.dart';

@JsGlobal()
abstract class Context extends JsInterface {

  factory Context() {}

  Context._create();

  JsFoo foo; // read a typed JS object from JS

  ExportMe exportMe; // write a exported Dart object to JS

}

@JsConstructor('JsThing')
abstract class JsFoo extends JsInterface {

  factory JsFoo(String name) {}

  JsFoo._create();

  String name;

  int y() => 1;

  JsBar bar;

  JsBar getBar(JsBar b);

}

@JsConstructor('JsThing2')
abstract class JsBar extends JsInterface {

  int y;

}

@Export()
class ExportMe {

  static String staticField = 'a';
  static bool staticMethod() => false;

  String field;

  int method() => 42;

  bool get getter => true;

  String _privateMethod() => "privateMethod";

  String _privateField = "privateField";

  void optionalArgs(a, [b, c]) {
    print("a: $a");
    print("b: $b");
    print("c: $c");
  }

  void namedArgs(a, {b, c}) {
    print("a: $a");
    print("b: $b");
    print("c: $c");
  }

}

@NoExport()
class DoNotExport {
  String field;
  bool get getter => false;
}

String topLevelField = "aardvark";

@Export()
DoNotExport getDoNotExport() => new DoNotExport();

@NoExport()
void main() {
}
