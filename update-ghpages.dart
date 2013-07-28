import 'package:ghpages_generator/ghpages_generator.dart' as gh;

main() {
  new gh.Generator()
  ..setDartDoc(['lib/js.dart'], excludedLibs: ['metadata'], outDir: 'docs')
  ..setExamples(true)
  ..templateDir = 'gh-pages-template'
  ..generate();
}