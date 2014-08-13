library js.test.transformer.utils;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';

// TODO: might need all visible implentations of List and Map in dart:*
// and all transferrable native objects supported by dart:js
final mockSdkSources = {
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

class TestUriResolver extends UriResolver {
  final Map<String, String> sources;

  TestUriResolver(this.sources);

  Source resolveAbsolute(Uri uri) {
    var name = uri.toString();
    var contents = sources[name];
    return new StringSource(contents, name);
  }

  Source fromEncoding(UriKind kind, Uri uri) =>
      throw new UnsupportedError('fromEncoding is not supported');

  Uri restoreAbsolute(Source source) =>
      throw new UnsupportedError('restoreAbsolute is not supported');
}
