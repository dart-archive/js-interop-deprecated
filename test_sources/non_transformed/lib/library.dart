// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.library;

import 'dart:js' show JsObject;
import 'package:js/js.dart';

abstract class Context extends JsInterface {

  factory Context() => new ContextImpl();

  Context.created(JsObject o) : super.created(o);

  String get aString;
  void set aString(String v);

  num get aNum;
  void set aNum(num v);

  bool get aBool;
  void set aBool(bool v);

  String get a;
  void set a(String v);

  JsFoo get foo;
  void set foo(JsFoo v);

  String getName(HasName o);

  bool isExportMe(ExportMe e);

  ExportMe roundTrip(ExportMe e);

  ExportMe createExportMe();

  int x();
}

@JsProxy(global: true)
class ContextImpl extends Context {

  factory ContextImpl() => new JsInterface(ContextImpl, []);

  ContextImpl.created(JsObject o) : super.created(o);

  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class HasName {
  String name;
}

abstract class JsFoo extends JsInterface {

  JsFoo.created(JsObject o) : super.created(o);

  factory JsFoo(String name) => new JsInterface(JsFooImpl, [name]);

  String get name;

  int y() => 1;

//  JsBar bar;
//
//  JsBar getBar(JsBar b);
}

@JsProxy(constructor: 'JsThing')
class JsFooImpl extends JsFoo {

  JsFooImpl.created(JsObject o) : super.created(o);

  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class JsBar extends JsFoo {

  factory JsBar(String name) => new JsInterface(JsBarImpl, [name]);

  JsBar.created(JsObject o) : super.created(o);

  int z();

}

@JsProxy(constructor: 'JsThing2')
class JsBarImpl extends JsBar {

  JsBarImpl.created(JsObject o) : super.created(o);

  noSuchMethod(i) => super.noSuchMethod(i);
}


@Export()
class ExportMe implements HasName {

  static String staticField = 'a';
  static bool staticMethod() => false;

  String name;

  ExportMe();

  ExportMe.named(this.name);

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
  initializeJavaScript();
}
