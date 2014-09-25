library js.static;

// This is the public interface of js.dart
// The exports must match those in static.dart
export 'package:js/src/js_impl.dart';
export 'dart:js' show JsObject;
export 'package:js/src/metadata.dart';

void initializeJavaScript() {
  throw new StateError("Non-transformed initialization is being called. "
      "You are using js.dart in deployed mode, but you probably haven't "
      "configured the initializer transformer, or you are calling "
      "initializeJavaScript() somewhere other than main(). "
      "Try adding '- js/initializer' to your applications transformers.");
}
