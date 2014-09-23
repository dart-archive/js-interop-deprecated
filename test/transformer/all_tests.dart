library js.test.transformer.all_tests;

import 'dart_initializer_generator_test.dart' as initializer_generator;
import 'entry_point_transformer_test.dart' as entry_point_transformer;
import 'html_transformer_test.dart' as html_transformer;
import 'js_proxy_generator_test.dart' as proxy_generator;
import 'library_transformer_test.dart' as library_transformer;
import 'scanning_visitor_test.dart' as scanning_visitor;

main() {
  entry_point_transformer.main();
  html_transformer.main();
  initializer_generator.main();
  library_transformer.main();
  proxy_generator.main();
  scanning_visitor.main();
}
