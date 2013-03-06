library tests;

import 'dart:html';
import 'dart:json';

import 'package:js/js.dart' as js;
import 'package:js/js_wrapping.dart' as jsw;
import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';

abstract class _Person {
  String firstname;

  String sayHello();
}
class PersonMP extends jsw.MagicProxy implements _Person {
  PersonMP(String firstname,  String lastname) :
      super(js.context.Person, [firstname, lastname]);
  PersonMP.fromJsProxy(js.Proxy proxy) : super.fromProxy(proxy);
}

class PersonTP extends jsw.TypedProxy {
  PersonTP(String firstname,  String lastname) :
      super(js.context.Person, [firstname, lastname]);
  PersonTP.fromProxy(js.Proxy proxy) : super.fromProxy(proxy);

  set firstname(String firstname) => $unsafe.firstname = firstname;
  String get firstname => $unsafe.firstname;

  String sayHello() => $unsafe.sayHello();
}

class Color implements js.Serializable<String> {
  static final RED = new Color._("red");
  static final BLUE = new Color._("blue");

  final String _value;

  Color._(this._value);

  String toJs() => this._value;
  operator ==(Color other) => this._value == other._value;
}

main() {
  useHtmlConfiguration();

  test('TypedProxy', () {
    js.scoped(() {
      final john = new PersonTP('John', 'Doe');
      expect(john.firstname, equals('John'));
      john.firstname = 'Joe';
      expect(john.firstname, equals('Joe'));
    });
  });

  test('MagicProxy', () {
    js.scoped(() {
      final john = new PersonMP('John', 'Doe');
      expect(john.firstname, equals('John'));
      expect(john['firstname'], equals('John'));
      john.firstname = 'Joe';
      expect(john.firstname, equals('Joe'));
      expect(john['firstname'], equals('Joe'));
      john['firstname'] = 'John';
      expect(john.firstname, equals('John'));
      expect(john['firstname'], equals('John'));
    });
  });

  test('function call', () {
    js.scoped(() {
      final john = new PersonTP('John', 'Doe');
      expect(john.sayHello(), equals("Hello, I'm John Doe"));
    });
  });

  test('JsDateToDateTimeAdapter', () {
    js.scoped(() {
      final date = new DateTime.now();
      final jsDate = new jsw.JsDateToDateTimeAdapter(date);
      expect(jsDate.millisecondsSinceEpoch,
          equals(date.millisecondsSinceEpoch));
      jsDate.$unsafe.setFullYear(2000);
      expect(jsDate.year, equals(2000));
    });
  });

  group('JsArrayToListAdapter', () {
    test('operations', () {
      js.scoped(() {
        js.context.myArray = js.array([]);

        final myArray = new jsw.JsArrayToListAdapter<String>.fromProxy(
            js.context.myArray);
        expect(myArray.length, equals(0));
        // []

        myArray.add("e0");
        expect(myArray.length, equals(1));
        expect(myArray[0], equals("e0"));
        // ["e0"]

        myArray.addAll(["e1", "e2"]);
        expect(myArray.length, equals(3));
        expect(myArray[0], equals("e0"));
        expect(myArray[1], equals("e1"));
        expect(myArray[2], equals("e2"));
        expect(myArray.first, equals("e0"));
        expect(myArray.last, equals("e2"));
        // ["e0", "e1", "e2"]

        myArray.length = 5;
        expect(myArray.length, equals(5));
        expect(myArray[0], equals("e0"));
        expect(myArray[1], equals("e1"));
        expect(myArray[2], equals("e2"));
        expect(myArray[3], isNull);
        expect(myArray[4], isNull);
        // ["e0", "e1", "e2", null, null]

        // TODO temporary disable : ".length=" is not call on MyArray :/
        //expect(() => myArray.length = 0, throws);
        expect(myArray.length, equals(5));
        // ["e0", "e1", "e2", null, null]

        myArray[3] = "e4";
        myArray[4] = "e3";
        expect(myArray.length, equals(5));
        expect(myArray[3], equals("e4"));
        expect(myArray[4], equals("e3"));
        // ["e0", "e1", "e2", "e4", "e3"]

        myArray.sort((String a, String b) => a.compareTo(b));
        expect(myArray.length, equals(5));
        expect(myArray[0], equals("e0"));
        expect(myArray[1], equals("e1"));
        expect(myArray[2], equals("e2"));
        expect(myArray[3], equals("e3"));
        expect(myArray[4], equals("e4"));
        // ["e0", "e1", "e2", "e3", "e4"]

        expect(myArray.removeAt(4), equals("e4"));
        expect(myArray.length, equals(4));
        expect(myArray[0], equals("e0"));
        expect(myArray[1], equals("e1"));
        expect(myArray[2], equals("e2"));
        expect(myArray[3], equals("e3"));
        // ["e0", "e1", "e2", "e3"]

        expect(myArray.removeLast(), equals("e3"));
        expect(myArray.length, equals(3));
        expect(myArray[0], equals("e0"));
        expect(myArray[1], equals("e1"));
        expect(myArray[2], equals("e2"));
        // ["e0", "e1", "e2"]

        final iterator = myArray.iterator;
        iterator.moveNext();
        expect(iterator.current, equals("e0"));
        iterator.moveNext();
        expect(iterator.current, equals("e1"));
        iterator.moveNext();
        expect(iterator.current, equals("e2"));

        myArray.clear();
        expect(myArray.length, equals(0));
        // []

        myArray.insertRange(0, 5, "a");
        expect(myArray.length, equals(5));
        for (final s in myArray) {
          expect(s, equals("a"));
        }
        // ["a", "a", "a", "a", "a"]
      });
    });

    test('bidirectionnal serialization of Proxy', () {
      js.scoped(() {
        js.context.myArray = js.array([]);
        final myList = new jsw.JsArrayToListAdapter<PersonTP>.fromProxy(
            js.context.myArray, new jsw.TranslatorForProxy<PersonTP>((p) =>
                new PersonTP.fromProxy(p)));

        myList.add(new PersonTP('John', 'Doe'));
        expect(myList[0].firstname, 'John');
      });
    });

    test('bidirectionnal serialization of Serializable', () {
      js.scoped(() {
        js.context.myArray = js.array([]);
        final myList = new jsw.JsArrayToListAdapter<Color>.fromProxy(
            js.context.myArray,
            new jsw.Translator<Color>((e) => new Color._(e), (e) => e.toJs()));

        myList.add(Color.BLUE);
        expect(myList[0], Color.BLUE);
      });
    });
  });

  test('retain/release', () {
    PersonTP john;
    js.scoped(() {
      john = new PersonTP('John', 'Doe');
    });
    js.scoped((){
      expect(() => john.sayHello(), throws);
    });
    js.scoped(() {
      john = new PersonTP('John', 'Doe');
      js.retain(john);
    });
    js.scoped((){
      expect(() => john.sayHello(), returnsNormally);
      js.release(john);
    });
    js.scoped((){
      expect(() => john.sayHello(), throws);
    });
  });
}
