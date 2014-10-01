// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.test.all_tests;

import 'transformer/all_tests.dart' as transformer;
import 'js_elements_test.dart' as js_elements;
import 'proxy_creator_test.dart' as proxy_creator;

main() {
  js_elements.main();
  transformer.main();
  proxy_creator.main();
}
