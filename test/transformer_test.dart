import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:code_transformers/src/test_harness.dart';
import 'package:code_transformers/resolver.dart';
import 'package:js/transformer.dart';

main() {

  group('FindExports', () {

    setUp(() {

    });

    test('x', () {
      var resolvers = new Resolvers(dartSdkDirectory);
      var transformer = new FindExports(['web/test.dart'], resolvers);
      var typedJs = new File('../lib/export_to_js.dart').readAsStringSync();
      print(typedJs);
      var testHelper = new TestHelper([[transformer]], {
        'js|lib/export_to_js.dart': typedJs,
        'test|web/test.dart': testDart,
        'test|web/test.html': testHtml
      }, null);
      testHelper.run(['test|web/test.dart']);
      return testHelper.check('test|web/test.dart.exports.js', '');
    });
  });
}


String testDart = '''
@Export()
library js_interop_test;

import 'package:js/export_to_js.dart';

@Export()
class ExportMe {
  String foo;

  int num() => 42;

  bool get flag => true;
}

void main() {
  print('hello world');
}
''';

String testHtml = '''
<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8">
    <title>Js interop test</title>
  </head>
  <body>
    <h1>Js interop test</h1>
    
    <script type="application/dart" src="js_interop_test.dart"></script>
    <script src="packages/browser/interop.js"></script>
    <script src="packages/browser/dart.js"></script>
    <script src="js_interop_test.dart.exports.js"></script>
  </body>
</html>
''';
