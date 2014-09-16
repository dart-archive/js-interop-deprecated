// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.transformer.utils;

import 'dart:io';

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/string_source.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:code_transformers/resolver.dart';
import 'package:js/src/transformer/mock_sdk.dart' as mock_sdk show sources;
import 'package:path/path.dart' as path;
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/java_io.dart';

class AnalyzerInfo {
  final AnalysisContext context;
  final LibraryElement testLib;
  final LibraryElement jsLib;

  AnalyzerInfo(this.context, this.testLib, this.jsLib);
}

final testSourcesPath = Directory.current.path.endsWith('transformer')
    ? 'test_sources'
    : 'transformer/test_sources';

final jsSourcesPath = Directory.current.path.endsWith('transformer')
    ? '../../lib/'
    : '../lib/';

String readJsPackageFile(String f) => new File(path.join(jsSourcesPath, f))
    .readAsStringSync();

String readTestFile(String f) => new File(path.join(testSourcesPath, f))
    .readAsStringSync();


AnalyzerInfo initAnalyzer() {
  // fix up cwd to be able to load test files when run from different
  // directories in the command line or Editor

  var _context = AnalysisEngine.instance.createAnalysisContext();
  var sdk = new MockDartSdk(mock_sdk.sources, reportMissing: false);
  var options = new AnalysisOptionsImpl();
  _context.analysisOptions = options;
  sdk.context.analysisOptions = options;

  var testLibSource = new File(path.join(testSourcesPath,'test.dart'))
      .readAsStringSync();
  var testSources = {
    'package:test/test.dart': testLibSource,
  };

  var testResolver = new TestUriResolver(testSources);

  var packagesDirectory = new JavaFile.fromUri(Uri.parse('packages'));
  var packageResolver = new PackageUriResolver([packagesDirectory]);

  _context.sourceFactory = new SourceFactory(
      [sdk.resolver, testResolver, packageResolver]);

  var testSource = testResolver
      .resolveAbsolute(Uri.parse('package:test/test.dart'));
  _context.parseCompilationUnit(testSource);

  Source jsSource = packageResolver
      .resolveAbsolute(Uri.parse('package:js/js.dart'));
  Source jsInterfaceSource = packageResolver
      .resolveAbsolute(Uri.parse('package:js/src/js_impl.dart'));
  Source jsMetadataSource = packageResolver
      .resolveAbsolute(Uri.parse('package:js/src/metadata.dart'));

  var jsLib = _context.computeLibraryElement(jsSource);
  var jsInterfaceLib = _context.computeLibraryElement(jsInterfaceSource);
  var testLib = _context.computeLibraryElement(testSource);

  return new AnalyzerInfo(_context, testLib, jsLib);
}

class TestUriResolver extends UriResolver {
  final Map<String, String> sources;

  TestUriResolver(this.sources);

  Source resolveAbsolute(Uri uri) {
    var name = uri.toString();
    if (!sources.containsKey(name)) return null;
    var contents = sources[name];
    return new StringSource(contents, name);
  }

  Source fromEncoding(UriKind kind, Uri uri) =>
      throw new UnsupportedError('fromEncoding is not supported');

  Uri restoreAbsolute(Source source) =>
      throw new UnsupportedError('restoreAbsolute is not supported');
}

Resolvers mockResolvers() => new Resolvers.fromMock(mock_sdk.sources);

