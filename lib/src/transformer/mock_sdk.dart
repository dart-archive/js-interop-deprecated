// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.mock_sdk;

// TODO: might need all transferrable native objects supported by dart:js
final sources = {
  'dart:core': '''
      library dart.core;
      class Object {}
      class Function {}
      class StackTrace {}
      class Symbol {}
      class Type {}
      class Expando<T> {}

      class String extends Object {}
      class bool extends Object {}
      class num extends Object {}
      class int extends num {}
      class double extends num {}
      class DateTime extends Object {}
      class Null extends Object {}

      class Deprecated extends Object {
        final String expires;
        const Deprecated(this.expires);
      }
      const Object deprecated = const Deprecated("next release");
      class _Override { const _Override(); }
      const Object override = const _Override();
      class _Proxy { const _Proxy(); }
      const Object proxy = const _Proxy();

      class List<V> extends Object {}
      class Map<K, V> extends Object {}

      void print(String s);
      ''',
  'dart:html': '''
      library dart.html;
      class HtmlElement {}
      ''',
  'dart:js': '''
      class JsObject {}
      JsObject context;
      '''
};
