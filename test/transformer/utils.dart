library js.test.transformer.utils;

import 'dart:io';

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:code_transformers/resolver.dart';
import 'package:js/src/transformer/mock_sdk.dart' as mock_sdk show sources;
import 'package:path/path.dart' as path;
import 'package:analyzer/src/generated/element.dart';

class AnalyzerInfo {
  final AnalysisContext context;
  final LibraryElement testLib;
  final LibraryElement jsLib;

  AnalyzerInfo(this.context, this.testLib, this.jsLib);
}

AnalyzerInfo initAnalyzer() {
  // fix up cwd to be able to load test files when run from different
  // directories in the command line or Editor
  var testSourcesPath = Directory.current.path.endsWith('transformer')
      ? 'test_sources'
      : 'transformer/test_sources';
  var jsSourcesPath = Directory.current.path.endsWith('transformer')
      ? '../../lib/'
      : '../lib/';

  var _context = AnalysisEngine.instance.createAnalysisContext();
  var sdk = new MockDartSdk(mock_sdk.sources, reportMissing: false);
  var options = new AnalysisOptionsImpl();
  _context.analysisOptions = options;
  sdk.context.analysisOptions = options;

  var testLibSource = new File(path.join(testSourcesPath,'test.dart'))
      .readAsStringSync();
  var testSources = {
    'package:js/js.dart':
        new File(path.join(jsSourcesPath,'js.dart')).readAsStringSync(),
    'package:test/test.dart': testLibSource,
  };
  var testResolver = new TestUriResolver(testSources);
  _context.sourceFactory = new SourceFactory([sdk.resolver, testResolver]);

  var testSource = testResolver
      .resolveAbsolute(Uri.parse('package:test/test.dart'));
  _context.parseCompilationUnit(testSource);

  var jsSource = testResolver
      .resolveAbsolute(Uri.parse('package:js/js.dart'));

  var testLib = _context.computeLibraryElement(testSource);
  var jsLib = _context.getLibraryElement(jsSource);
  return new AnalyzerInfo(_context, testLib, jsLib);
}

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
