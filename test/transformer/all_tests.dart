library js.test.transformer.all_tests;

import 'js_initializer_generator_test.dart' as initializer_generator;
import 'js_proxy_generator_test.dart' as proxy_generator;
import 'library_transformer_test.dart' as library_transformer;
import 'scanning_visitor_test.dart' as scanning_visitor;

main() {
  initializer_generator.main();
  proxy_generator.main();
  library_transformer.main();
  scanning_visitor.main();
}
