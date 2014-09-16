// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer_test;

import 'dart:js' show JsObject;
import 'package:js/js.dart';
import 'package:js/src/js_impl.dart' as jsi;
import 'dart:js' as djs;

abstract class Context extends JsInterface {

//  factory Context() => new JsInterface(ContextImpl, []);
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

class ContextImpl extends Context {

  static Context _instance;

  factory ContextImpl() => (_instance != null) ? _instance : _instance = new ContextImpl.created(jsi.context);

  ContextImpl.created(JsObject o) : super.created(o);

  String get aString => jsi.toDart(jsi.toJs(this)['aString']) as String;
  void set aString(String v) { jsi.toJs(this)['aString'] = jsi.toJs(v); }

  num get aNum => jsi.toDart(jsi.toJs(this)['aNum']) as num;
  void set aNum(num v) { jsi.toJs(this)['aNum'] = jsi.toJs(v); }

  bool get aBool => jsi.toDart(jsi.toJs(this)['aBool']) as bool;
  void set aBool(bool v) { jsi.toJs(this)['aBool'] = jsi.toJs(v); }

  String get a => jsi.toDart(jsi.toJs(this)['a']) as String;
  void set a(String v) { jsi.toJs(this)['a'] = jsi.toJs(v); }

  JsFoo get foo => jsi.toDart(jsi.toJs(this)['foo']) as JsFoo;
  void set foo(JsFoo v) { jsi.toJs(this)['foo'] = jsi.toJs(v); }

  String getName(HasName o) => jsi.toJs(this).callMethod('getName', [jsi.toJs(o)]) as String;

  bool isExportMe(ExportMe o) => jsi.toJs(this).callMethod('isExportMe', [jsi.toJs(o)]) as bool;

  ExportMe roundTrip(ExportMe e) => jsi.toDart(jsi.toJs(this).callMethod('roundTrip', [jsi.toJs(e)])) as ExportMe;

  ExportMe createExportMe() => jsi.toDart(jsi.toJs(this).callMethod('createExportMe', [])) as ExportMe;

  int x() => jsi.toJs(this).callMethod('x', []) as int;
}

abstract class HasName {
  String get name;
}

abstract class JsFoo extends JsInterface implements HasName {

  JsFoo.created(JsObject o) : super.created(o);

//  factory JsFoo(String name) => new JsInterface(JsFooImpl, [name]);
  factory JsFoo(String name) => new JsFooImpl(name);

  String get name;

  int y() => 1;

//  JsBar bar;
//
//  JsBar getBar(JsBar b);
}

class JsFooImpl extends JsFoo {

  factory JsFooImpl(String name) =>
      new JsFooImpl.created(new JsObject(jsi.context['JsThing'], [name]));

  JsFooImpl.created(JsObject o) : super.created(o);

  String get name => jsi.toDart(jsi.toJs(this)['name']) as String;

//  JsBar bar;
//  JsBar get bar => jsi.getJsObject(this)['bar'];
//  void set bar(JsBar v) { jsi.getJsObject(this)['bar'] = v; }
//
//  JsBar getBar(JsBar b) => jsi.getJsObject(this).callMethod('getBar', []);
}

abstract class JsBar extends JsFoo {

//  factory JsBar(String name) => new JsInterface(JsBarImpl, [name]);
  factory JsBar(String name) => new JsBarImpl(name);

  JsBar.created(JsObject o) : super.created(o);

  int z();
}


class JsBarImpl extends JsBar {

  factory JsBarImpl(String name) =>
      new JsBarImpl.created(new JsObject(jsi.context['JsThing2'], [name]));

  JsBarImpl.created(o) : super.created(o);

  String get name => jsi.toDart(jsi.toJs(this)['name']) as String;

//  int z();
  int z() => jsi.toJs(this).callMethod('z', []) as int;
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
//
//@NoExport()
//class DoNotExport {
//  String field;
//  bool get getter => false;
//}
//
//String topLevelField = "aardvark";
//
//@Export()
//DoNotExport getDoNotExport() => new DoNotExport();

@NoExport()
void main() {
  initializeJavaScript();
}

// hand-generated export code derived from this library

final _obj = djs.context['Object'];
final _dartNs = djs.context['dart'];

Object _getOptionalArg(Map<String, Object> args, String name) =>
  args == null ? null : args[name];

void initializeJavaScript() {
  // register Dart factories for JavaScript constructors
  jsi.registerFactoryForJsConstructor(jsi.context['JsThing'], (jsi.JsObject o) => new JsFooImpl.created(o));
  jsi.registerFactoryForJsConstructor(jsi.context['JsThing2'], (jsi.JsObject o) => new JsBarImpl.created(o));

  // export Dart APIs to JavaScript
  var lib = _dartNs;
  assert(_dartNs != null);
  _export_js(lib);
}

void _export_js(djs.JsObject parent) {
  var lib = parent['js'];
  _export_js_transformer__test(lib);
}

void _export_js_transformer__test(djs.JsObject parent) {
  var lib = parent['transformer_test'];
  _export_js_transformer__test_ExportMe(lib);
}

void _export_js_transformer__test_ExportMe(djs.JsObject parent) {
  var constructor = parent['ExportMe'];
  jsi.registerJsConstructorForType(ExportMe, constructor['_wrapDartObject']);
  var prototype = constructor['prototype'];

  // implicit constructor
  constructor['_new'] = () => new ExportMe();

  // named constructor 'named'
  constructor['_new_named'] = (String name) => new ExportMe.named(name);

  // field 'name'
  _obj.callMethod('defineProperty', [prototype, 'name',
      new djs.JsObject.jsify({
        'get': new djs.JsFunction.withThis((o) => (o[jsi.DART_OBJECT_PROPERTY] as ExportMe).name),
        'set': new djs.JsFunction.withThis((o, v) => (o[jsi.DART_OBJECT_PROPERTY] as ExportMe).name = v),
      })]);

  // method 'method'
  prototype['method'] = new djs.JsFunction.withThis((__js_this_ref__) {
    return (__js_this_ref__[jsi.DART_OBJECT_PROPERTY] as ExportMe).method();
  });

}
