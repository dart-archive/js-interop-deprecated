#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library build;

import 'dart:io';

import 'package:path/path.dart' as path;

import 'tool/create_bootstrap.dart' as createBootstrap;

void main() {
  final options = new Options();
  final scriptPath = path.dirname(options.script);
  final libPath = path.join(scriptPath, 'lib');

  final changedOpt = "--changed=" +
      path.normalize(path.join(libPath, 'js.dart'));
  for (String arg in new Options().arguments) {
    if (arg == changedOpt) {
      createBootstrap.create(libPath);
    }
  }
}
