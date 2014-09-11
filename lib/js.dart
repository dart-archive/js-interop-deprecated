// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * The js library allows Dart library authors to export their APIs to JavaScript
 * and to define Dart interfaces for JavaScript objects.
 */
library js;

export 'dart:js' show JsObject;

// this must be a package import due to dartbug.com/20666
export 'package:js/src/js_impl.dart' show JsInterface;
export 'package:js/src/metadata.dart';
import 'package:js/src/mirrors.dart' as impl show initializeJavaScript;

void initializeJavaScript() => impl.initializeJavaScript();