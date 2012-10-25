#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This utility carves out the embedded bootstrap JavaScript in
 * js.dart as a separate file that may be included directly in html.
 * This is necessary in settings where script injection is disallowed.
 *
 * To run, navigate to the top-level directory for this project and run:
 *   .../dart ./tools/create_bootstrap.dart
 */
library create_bootstrap;

import 'dart:io';

final JS_PATTERN = const RegExp(r'final _JS_BOOTSTRAP = r"""((.*\n)*)""";');

final HEADER = """
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// THIS FILE IS AUTO GENERATED.  PLEASE DO NOT EDIT.

// TODO(vsm): Move this file once we determine where assets should go.  See
// http://dartbug.com/6101.
""";

create(Path path, String text) {
  final js = JS_PATTERN.firstMatch(text).group(1);
  final out = new File.fromPath(path.join(new Path('../lib/dart_interop.js')));
  out.create()
    .then((out) => out.open(FileMode.WRITE)
      .then((file) => file.writeString(HEADER)
        .then((file) => file.writeString(js)
          .then((file) => file.close()))));
}

main() {
  final options = new Options();
  final path = new Path(options.script).directoryPath;
  final f = new File.fromPath(path.join(new Path('../lib/js.dart')));
  f.readAsText().then((text) => create(path, text));
}
