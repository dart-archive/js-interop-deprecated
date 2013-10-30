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

import 'package:path/path.dart' as path;

final JS_PATTERN = new RegExp(r'final _JS_BOOTSTRAP = r"""((.*\n)*)""";');

final HEADER = """
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// THIS FILE IS AUTO GENERATED.  PLEASE DO NOT EDIT.

// TODO(vsm): Move this file once we determine where assets should go.  See
// http://dartbug.com/6101.
""";

createFile(String source, String target) {
  print('hello');
  final f = new File(source);
  f.readAsString()
    .then((text) {
      final js = JS_PATTERN.firstMatch(text).group(1);
      final out = new File(target);
      out.create()
        .then((out) => out.open(mode: FileMode.WRITE)
          .then((file) => file.writeString(HEADER)
            .then((file) => file.writeString(js)
              .then((file) => file.close()))));
    });
}

create(String libPath) {
  final source = path.join(libPath, 'js.dart');
  final target = path.join(libPath, 'dart_interop.js');
  createFile(source, target);
}

main() {
  final scriptPath = path.dirname(Platform.script);
  final libPath = path.join(scriptPath, '../lib');
  create(libPath);
}
