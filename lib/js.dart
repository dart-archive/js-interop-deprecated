// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * The js library allows Dart library authors to export their APIs to JavaScript
 * and to define Dart interfaces for JavaScript objects.
 */
library js;

// js.dart is just an alias for mirrors.dart at runtime. The transformer
// replaces this import of js.dart with src/static.dart.
export 'package:js/src/mirrors.dart';
export 'package:js/src/js_expando.dart' show JsExpando;
export 'package:js/src/js_list.dart' show JsList;
export 'package:js/src/js_map.dart' show JsMap;
