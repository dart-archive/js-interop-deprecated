// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:js/proxy_creator.dart';

main(List<String> args) {
  if (args.isEmpty) {
    print('You must provide one or more class names as arguments');
  }
  print(args.map(createProxySkeleton).join('\n\n'));
}
