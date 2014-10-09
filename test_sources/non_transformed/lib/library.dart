// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.library;

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

  DateTime get aDate;
  void set aDate(DateTime d);

  String get a;
  void set a(String v);

  JsFoo get foo;
  void set foo(JsFoo v);

  String getName(HasName o);

  void setName(HasName o, String name);

  int callMethod(ExportMe e);

  String callMethod2(ExportMe e, String a);

  String callOptionalArgs(ExportMe e);

  String callOptionalArgs2(ExportMe e);

  String callNamedArgs(ExportMe e);

  bool getGetter(ExportMe e);

  bool setSetter(ExportMe e, String s);

  bool isExportMe(ExportMe e);

  bool isDartObject(Object o);

  ExportMe roundTrip(ExportMe e);

  ExportMe createExportMe();

  ExportMe createExportMeNamed(String name);

  ExportMe createExportMeNamed2(String name);

  ExportMe createExportMeOptional(String name);

  int x();

  @JsName('aString') String get x_aString;

  @JsName('aString') void set x_aString(String v);

  @JsName('createExportMe') ExportMe x_createExportMe();
}

@JsProxy(global: true)
class ContextImpl extends Context implements JsGlobal {

  factory ContextImpl() => new JsInterface(ContextImpl, []);

  ContextImpl.created(JsObject o) : super.created(o);

  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class HasName {
  String name;
}

abstract class JsFoo extends JsInterface implements HasName {

  JsFoo.created(JsObject o) : super.created(o);

  factory JsFoo(String name) => new JsFooImpl(name);

  String get name;

  int y() => 1;

  num double(num x);

  String getName(HasName b);

  JsObject getAnonymous();

  void setAnonymous(JsObject o);

  void setBar(JsBar);

  JsBar get bar;
  void set bar(JsBar bar);
}

@JsProxy(constructor: 'JsThing')
class JsFooImpl extends JsFoo {

  factory JsFooImpl(String name) => new JsInterface(JsFooImpl, [name]);

  JsFooImpl.created(JsObject o) : super.created(o);

  noSuchMethod(i) => super.noSuchMethod(i);
}

abstract class JsBar extends JsFoo {

  factory JsBar(String name) => new JsBarImpl(name);

  JsBar.created(JsObject o) : super.created(o);

  int z();

}

@JsProxy(constructor: 'JsThing2')
class JsBarImpl extends JsBar {
  factory JsBarImpl(String name) => new JsInterface(JsBarImpl, [name]);

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

  ExportMe.named2({this.name});

  ExportMe.optional(this.name);

  int method() => 42;

  bool get getter => true;

  void set setter(String v) { name = v; }

  String _privateMethod() => "privateMethod";

  String _privateField = "privateField";

  String method2(String s) => "Hello $s!";

  String optionalArgs(int a, [int b, int c]) => '$a $b $c';

  String namedArgs(int a, {int b, int c}) => '$a $b $c';

  String toString() => 'ExportMe($name)';

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
