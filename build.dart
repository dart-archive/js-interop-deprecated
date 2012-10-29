#!/usr/bin/env dart

library build;

import 'tools/create_bootstrap.dart' as createBootstrap;
import 'dart:io';

void main() {
  final options = new Options();
  final scriptPath = new Path(options.script).directoryPath;
  final libPath = scriptPath.append('lib');
  createBootstrap.create(libPath);
}