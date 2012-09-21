// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * The js.dart library provides simple JavaScript invocation from Dart that
 * works on both Dartium and on other modern browsers via Dart2JS.
 *
 * It provides a model based on Scoped [Proxy] objects.  Proxies allow Dart
 * code to access JavaScript objects, fields, and functions naturally and
 * vice-versa.  Scopes enable developers to use proxies without memory leaks -
 * a common challenge with cross-runtime interoperation.
 *
 * The top-level [context] getter provides a [Proxy] to the global JavaScript
 * context for the page you are running on.  In the following example:
 *
 *     #import('package:js/js.dart', prefix: 'js');
 *
 *     void main() {
 *       js.scoped(() {
 *         js.context.alert('Hello from Dart via JavaScript');
 *       });
 *     }
 *
 * js.context.alert creates a proxy to the top-level alert function in
 * JavaScript.  It is invoked from Dart as a regular function that forwards to
 * the underlying JavaScript one.  The proxies allocated within the scope are
 * released once the scope is exited.
 *
 * The library also enables JavaScript proxies to Dart objects and functions.
 * For example, the following Dart code:
 *
 *     scoped(() {
 *       js.context.dartCallback = new Callback.once((x) => print(x*2));
 *     });
 *
 * defines a top-level JavaScript function 'dartCallback' that is a proxy to
 * the corresponding Dart function.  The [Callback.once] constructor allows the
 * proxy to the Dart function to be retained beyond the end of the scope;
 * instead it is released after the first invocation.  (This is a common
 * pattern for asychronous callbacks.)
 *
 * Note, parameters and return values are intuitively passed by value for
 * primitives and by reference for non-primitives.  In the latter case, the
 * references are automatically wrapped and unwrapped as proxies by the library.
 *
 * This library also allows construction of JavaScripts objects given a [Proxy]
 * to a corresponding JavaScript constructor.  For example, if the following
 * JavaScript is loaded on the page:
 *
 *     function Foo(x) {
 *       this.x = x;
 *     }
 *
 *     Foo.prototype.add = function(other) {
 *       return new Foo(this.x + other.x);
 *     }
 *
 * then, the following Dart:
 *
 *     var foo = new js.Proxy(js.context.Foo, 42);
 *     var foo2 = foo.add(foo);
 *     print(foo2.x);
 *
 * will construct a JavaScript Foo object with the parameter 42, invoke its
 * add method, and return a [Proxy] to a new Foo object whose x field is 84.
 *
 * See [samples](http://dart-lang.github.com/js-interop/) for more examples
 * of usage.
 */

// TODO(vsm): Add a link to an article.

#library('js');

#import('dart:html');
#import('dart:isolate');

// JavaScript bootstrapping code.
final _JS_BOOTSTRAP = @"""
(function() {
  // Proxy support

  // Table for local objects and functions that are proxied.
  // TODO(vsm): Merge into one.
  function ProxiedReferenceTable(name) {
    // Name for debugging.
    this.name = name;

    // Table from IDs to JS objects.
    this.map = {};

    // Generator for new IDs.
    this._nextId = 0;

    // Counter for deleted proxies.
    this._deletedCount = 0;

    // Flag for one-time initialization.
    this._initialized = false;

    // Ports for managing communication to proxies.
    this.port = new ReceivePortSync();
    this.sendPort = this.port.toSendPort();

    // Set of IDs that are global.
    // These will not be freed on an exitScope().
    this.globalIds = {};

    // Stack of scoped handles.
    this.handleStack = [];

    // Stack of active scopes where each value is represented by the size of
    // the handleStack at the beginning of the scope.  When an active scope
    // is popped, the handleStack is restored to where it was when the
    // scope was entered.
    this.scopeIndices = [];
  }

  // Number of valid IDs.  This is the number of objects (global and local)
  // kept alive by this table.
  ProxiedReferenceTable.prototype.count = function () {
    return Object.keys(this.map).length;
  }

  // Number of total IDs ever allocated.
  ProxiedReferenceTable.prototype.total = function () {
    return this.count() + this._deletedCount;
  }

  // Add an object to the table and return an ID for serialization.
  ProxiedReferenceTable.prototype.add = function (obj) {
    if (this.scopeIndices.length == 0) {
      throw "Cannot allocate a proxy outside of a scope.";
    }
    // TODO(vsm): Cache refs for each obj?
    var ref = this.name + '-' + this._nextId++;
    this.handleStack.push(ref);
    this.map[ref] = obj;
    return ref;
  }

  ProxiedReferenceTable.prototype._initializeOnce = function () {
    if (!this._initialized) {
      this._initialize();
    }
    this._initialized = true;
  }

  // Overridable initialization on first use hook.
  ProxiedReferenceTable.prototype._initialize = function () {}

  // Enter a new scope for this table.
  ProxiedReferenceTable.prototype.enterScope = function() {
    this._initializeOnce();
    this.scopeIndices.push(this.handleStack.length);
  }
  
  // Invalidate all non-global IDs in the current scope and
  // exit the current scope.
  ProxiedReferenceTable.prototype.exitScope = function() {
    var start = this.scopeIndices.pop();
    for (var i = start; i < this.handleStack.length; ++i) {
      var key = this.handleStack[i];
      if (!this.globalIds.hasOwnProperty(key)) {
        delete this.map[this.handleStack[i]];
        this._deletedCount++;
      }
    }
    this.handleStack = this.handleStack.splice(0, start);
  }
  
  // Make this ID globally scope.  It must be explicitly invalidated.
  ProxiedReferenceTable.prototype.globalize = function(id) {
    this.globalIds[id] = true;
  }

  // Invalidate this ID, potentially freeing its corresponding object.
  ProxiedReferenceTable.prototype.invalidate = function(id) {
    var old = this.get(id);
    delete this.globalIds[id];
    delete this.map[id];
    this._deletedCount++;
    return old;
  }

  // Get the object or function corresponding to this ID.
  ProxiedReferenceTable.prototype.get = function (id) {
    if (!this.map.hasOwnProperty(id)) {
      throw 'Proxy ' + id + ' has been invalidated.'
    }
    return this.map[id];
  }

  // Subtype for managing function proxies.
  function ProxiedFunctionTable() {}

  ProxiedFunctionTable.prototype = new ProxiedReferenceTable('func-ref');

  ProxiedFunctionTable.prototype._initialize = function () {
    // Configure this table's port to invoke the corresponding function given
    // its ID.
    // TODO(vsm): Should we enter / exit a scope?
    var table = this;

    this.port.receive(function (message) {
      var id = message[0];
      var args = message[1].map(deserialize);
      var f = table.get(id);
      // TODO(vsm): Should we capture _this_ automatically?
      return serialize(f.apply(null, args));
    });
  }

  // The singleton table for proxied local functions.
  var proxiedFunctionTable = new ProxiedFunctionTable();

  // Subtype for proxied local objects.
  function ProxiedObjectTable() {}

  ProxiedObjectTable.prototype = new ProxiedReferenceTable('js-ref');

  ProxiedObjectTable.prototype._initialize = function () {
    // Configure this table's port to forward methods, getters, and setters
    // from the remote proxy to the local object.
    var table = this;

    this.port.receive(function (message) {
      // TODO(vsm): Support a mechanism to register a handler here.
      var receiver = table.get(message[0]);
      var method = message[1];
      var args = message[2].map(deserialize);
      if (method.indexOf("get:") == 0) {
        // Getter.
        var field = method.substring(4);
        if (field in receiver && args.length == 0) {
          return [ 'return', serialize(receiver[field]) ];
        }
      } else if (method.indexOf("set:") == 0) {
        // Setter.
        var field = method.substring(4);
        if (args.length == 1) {
          return [ 'return', serialize(receiver[field] = args[0]) ];
        }
      } else if (method == '[]' && args.length == 1) {
        // Index getter.
        return [ 'return', serialize(receiver[args[0]]) ];
      } else {
        var f = receiver[method];
        if (f) {
          try {
            var result = f.apply(receiver, args);
            return [ 'return', serialize(result) ];
          } catch (e) {
            return [ 'exception', serialize(e) ];
          }
        }
      }
      return [ 'none' ];
    });
  }

  // Singleton for local proxied objects.
  var proxiedObjectTable = new ProxiedObjectTable();

  // DOM element serialization code.
  var _localNextElementId = 0;
  var _DART_ID = 'data-dart_id';

  function serializeElement(e) {
    // TODO(vsm): Check for collisions with existing DOM nodes.
    if (e.hasAttribute(_DART_ID)) return e.getAttribute(_DART_ID);
    var id = (_localNextElementId++).toString();
    e.setAttribute(_DART_ID, id);
    return id;
  }

  function deserializeElement(id) {
    // TODO(vsm): Clear the attribute.
    var list = document.querySelectorAll('[' + _DART_ID + '="' + id + '"]');

    if (list.length > 1) throw 'Non unique ID: ' + id;
    if (list.length == 0) {
      throw 'Element must be attached to the document: ' + id;
    }
    return list[0];
  }


  // Type for remote proxies to Dart objects.
  function DartProxy(id, sendPort) {
    this.id = id;
    this.port = sendPort;
  }

  // Serialize JS types to SendPortSync format:
  // - primitives -> primitives
  // - sendport -> sendport
  // - DOM element -> [ 'domref', element-id ]
  // - Function -> [ 'funcref', function-id, sendport ]
  // - Object -> [ 'objref', object-id, sendport ]
  function serialize(message) {
    if (message == null) {
      return null;  // Convert undefined to null.
    } else if (typeof(message) == 'string' ||
               typeof(message) == 'number' ||
               typeof(message) == 'boolean') {
      // Primitives are passed directly through.
      return message;
    } else if (message instanceof SendPortSync) {
      // Non-proxied objects are serialized.
      return message;
    } else if (message instanceof Element) {
      return [ 'domref', serializeElement(message) ];
    } else if (typeof(message) == 'function') {
      if ('_dart_id' in message) {
        // Remote function proxy.
        var remoteId = message._dart_id;
        var remoteSendPort = message._dart_port;
        return [ 'funcref', remoteId, remoteSendPort ];
      } else {
        // Local function proxy.
        return [ 'funcref',
                 proxiedFunctionTable.add(message),
                 proxiedFunctionTable.sendPort ];
      }
    } else if (message instanceof DartProxy) {
      // Remote object proxy.
      return [ 'objref', message.id, message.port ];
    } else {
      // Local object proxy.
      return [ 'objref',
               proxiedObjectTable.add(message),
               proxiedObjectTable.sendPort ];
    }
  }

  function deserialize(message) {
    if (message == null) {
      return null;  // Convert undefined to null.
    } else if (typeof(message) == 'string' ||
               typeof(message) == 'number' ||
               typeof(message) == 'boolean') {
      // Primitives are passed directly through.
      return message;
    } else if (message instanceof SendPortSync) {
      // Serialized type.
      return message;
    }
    var tag = message[0];
    switch (tag) {
      case 'funcref': return deserializeFunction(message);
      case 'objref': return deserializeObject(message);
      case 'domref': return deserializeElement(message[1]);
    }
    throw 'Unsupported serialized data: ' + message;
  }

  // Create a local function that forwards to the remote function.
  function deserializeFunction(message) {
    var id = message[1];
    var port = message[2];
    // TODO(vsm): Add a more robust check for a local SendPortSync.
    if ("receivePort" in port) {
      // Local function.
      return proxiedFunctionTable.get(id);
    } else {
      // Remote function.  Forward to its port.
      var f = function () {
        enterScope();
        try {
          var args = Array.prototype.slice.apply(arguments).map(serialize);
          var result = port.callSync([id, args]);
          return deserialize(result);
        } finally {
          exitScope();
        }
      };
      // Cache the remote id and port.
      f._dart_id = id;
      f._dart_port = port;
      return f;
    }
  }

  // Create a DartProxy to forwards to the remote object.
  function deserializeObject(message) {
    var id = message[1];
    var port = message[2];
    // TODO(vsm): Add a more robust check for a local SendPortSync.
    if ("receivePort" in port) {
      // Local object.
      return proxiedObjectTable.get(id);
    } else {
      // Remote object.
      return new DartProxy(id, port);
    }
  }

  // Remote handler to construct a new JavaScript object given its
  // serialized constructor and arguments.
  function construct(args) {
    args = args.map(deserialize);
    var constructor = args[0];
    args = Array.prototype.slice.call(args, 1);

    // Dummy Type with correct constructor.
    var Type = function(){};
    Type.prototype = constructor.prototype;

    // Create a new instance
    var instance = new Type();

    // Call the original constructor.
    var ret = constructor.apply(instance, args);

    return serialize(Object(ret) === ret ? ret : instance);
  }

  // Remote handler to evaluate a string in JavaScript and return a serialized
  // result. 
  function evaluate(data) {
    return serialize(eval(deserialize(data))); 
  }

  // Remote handler for debugging.
  function debug() {
    var live = proxiedObjectTable.count() + proxiedFunctionTable.count();
    var total = proxiedObjectTable.total() + proxiedFunctionTable.total();
    return 'JS objects Live : ' + live +
           ' (out of ' + total + ' ever allocated).';
  }

  function makeGlobalPort(name, f) {
    var port = new ReceivePortSync();
    port.receive(f);
    window.registerPort(name, port.toSendPort());
  }

  // Enter a new scope in the JavaScript context.
  function enterScope() {
    proxiedObjectTable.enterScope();
    proxiedFunctionTable.enterScope();
  }

  // Exit the current scope (and invalidate local IDs) in the JavaScript
  // context.
  function exitScope() {
    proxiedFunctionTable.exitScope();
    proxiedObjectTable.exitScope();
  }

  makeGlobalPort('dart-js-evaluate', evaluate);
  makeGlobalPort('dart-js-create', construct);
  makeGlobalPort('dart-js-debug', debug);
  makeGlobalPort('dart-js-enter-scope', enterScope);
  makeGlobalPort('dart-js-exit-scope', exitScope);
  makeGlobalPort('dart-js-globalize', function(data) {
    if (data[0] == "objref") return proxiedObjectTable.globalize(data[1]);
    // TODO(vsm): Do we ever need to globalize functions?
    throw 'Illegal type: ' + data[0];
  });
  makeGlobalPort('dart-js-invalidate', function(data) {
    if (data[0] == "objref") return proxiedObjectTable.invalidate(data[1]);
    // TODO(vsm): Do we ever need to globalize functions?
    throw 'Illegal type: ' + data[0];
  });
})();
""";

// Inject JavaScript source code onto the page.
// This is only used to load the bootstrapping code above.
void _inject(code) {
  final script = new ScriptElement();
  script.type = 'text/javascript';
  script.innerHTML = code;
  document.body.nodes.add(script);
}

// Global ports to manage communication between Dart and JS.
SendPortSync _jsPortSync = null;
SendPortSync _jsPortCreate = null;
SendPortSync _jsPortDebug = null;
SendPortSync _jsEnterScope = null;
SendPortSync _jsExitScope = null;
SendPortSync _jsGlobalize = null;
SendPortSync _jsInvalidate = null;

// Initialize bootstrap code and ports.
void _initialize() {
  if (_jsPortSync != null) return;
  _inject(_JS_BOOTSTRAP);
  _jsPortSync = window.lookupPort('dart-js-evaluate');
  _jsPortCreate = window.lookupPort('dart-js-create');
  _jsPortDebug = window.lookupPort('dart-js-debug');
  _jsEnterScope = window.lookupPort('dart-js-enter-scope');
  _jsExitScope = window.lookupPort('dart-js-exit-scope');
  _jsGlobalize = window.lookupPort('dart-js-globalize');
  _jsInvalidate = window.lookupPort('dart-js-invalidate');

  // Set up JS debugging.
  scoped(() {
    context.dartProxyDebug = new Callback.many(proxyDebug);
  });
}

// Evaluate a JavaScript string and return
_js(String message) => _deserialize(_jsPortSync.callSync(_serialize(message)));

/**
 * Return a proxy to the global JavaScript context for this page.
 */
Proxy get context {
  if (_depth == 0) throw 'Cannot get JavaScript context out of scope.';
  return _js('window');
}

// Depth of current scope.  Return 0 if no scope.
get _depth => _proxiedObjectTable._scopeIndices.length;

/**
 * Execute the closure [f] within a scope.  Any proxies created within this
 * scope are invalidated afterward unless they are converted to a global proxy.
 */
scoped(f) {
  var depth = _enterScope();
  try {
    return f();
  } finally {
    _exitScope(depth);
  }
}

_enterScope() {
  _initialize();
  _proxiedObjectTable.enterScope();
  _proxiedFunctionTable.enterScope();
  assert(_proxiedObjectTable._scopeIndices.length ==
         _proxiedFunctionTable._scopeIndices.length);
  _jsEnterScope.callSync([]);
  return _proxiedObjectTable._scopeIndices.length;
}

_exitScope(depth) {
  assert(_proxiedObjectTable._scopeIndices.length == depth);
  _jsExitScope.callSync([]);
  _proxiedFunctionTable.exitScope();
  _proxiedObjectTable.exitScope();
  proxyDebug();
}

/**
 * Retain the given [proxy] beyond the current scope.
 * Instead, it will need to be explicitly released.
 * The given [proxy] is returned for convenience.
 */
Proxy retain(Proxy proxy) {
  _jsGlobalize.callSync(_serialize(proxy));
  return proxy;
}

/**
 * Release a retained [proxy].
 */
void release(Proxy proxy) {
  _jsInvalidate.callSync(_serialize(proxy));
}


/**
 * Convert a Dart map [data] to a JavaScript map and return a [Proxy] to it.
 */
Proxy map(Map data) => new Proxy._json(data);

/**
 * Convert a Dart [list] to a JavaScript array and return a [Proxy] to it.
 */
Proxy array(List list) => new Proxy._json(list);

/**
 * Convert a local Dart function to a callback that can be passed to
 * JavaScript.
 *
 * A callback can either be:
 *
 * - single-fire, in which case it is automatically invalidated after the first
 *   invocation, or
 * - multi-fire, in which case it must be explicitly disposed.
 */
class Callback {
  var _manualDispose;
  var _id;
  var _callback;

  get _serialized => [ 'funcref',
                       _id,
                       _proxiedFunctionTable.sendPort ];

  _initialize(f, manualDispose) {
    _manualDispose = manualDispose;
    _id = _proxiedFunctionTable.add(f);
    _proxiedFunctionTable.globalize(_id);

    _proxiedFunctionTable._replace(_id, _callback);
    _deserializedFunctionTable.add(_callback, _serialized);
  }

  _dispose() {
    var c = _proxiedFunctionTable.invalidate(_id);
    _deserializedFunctionTable.remove(c);
  }

  /**
   * Dispose this [Callback] so that it may be collected.
   * Once a [Callback] is disposed, it is an error to invoke it from JavaScript.
   */
  dispose() {
    assert(_manualDispose);
    _dispose();
  }

  /**
   * Create a single-fire [Callback] that invokes [f].  The callback is
   * automatically disposed after the first invocation.
   */
  // TODO(vsm): Is there a better way to handle varargs?
  Callback.once(Function f) {
    _callback = ([arg1, arg2, arg3, arg4]) {
      try {
        if (!?arg1) {
          return scoped(() => f());
        } else if (!?arg2) {
          return scoped(() => f(arg1));
        } else if (!?arg3) {
          return scoped(() => f(arg1, arg2));
        } else if (!?arg4) {
          return scoped(() => f(arg1, arg2, arg3));
        } else {
          return scoped(() => f(arg1, arg2, arg3, arg4));
        }
      } finally {
        _dispose();
      }
    };
    _initialize(f, false);
  }

  /**
   * Create a multi-fire [Callback] that invokes [f].  The callback must be
   * explicitly disposed to avoid memory leaks.
   */
  // TODO(vsm): Is there a better way to handle varargs?
  Callback.many(Function f) {
    _callback = ([arg1, arg2, arg3, arg4]) {
      if (!?arg1) {
        return scoped(() => f());
      } else if (!?arg2) {
        return scoped(() => f(arg1));
      } else if (!?arg3) {
        return scoped(() => f(arg1, arg2));
      } else if (!?arg4) {
        return scoped(() => f(arg1, arg2, arg3));
      } else {
        return scoped(() => f(arg1, arg2, arg3, arg4));
      }
    };
    _initialize(f, false);
  }
}

/**
 * Proxies to JavaScript objects.
 */
class Proxy {
  SendPortSync _port;
  final _id;

  /**
   * Construct a [Proxy] to a new JavaScript object by invoking a (proxy to a)
   * JavaScript [constructor].  The arguments should be either
   * primitive values, DOM elements, or Proxies.
   */
  factory Proxy(constructor, [arg1, arg2, arg3, arg4]) {
    if (_depth == 0) throw 'Cannot create Proxy out of scope.';
    var serialized = [constructor, arg1, arg2, arg3, arg4].map(_serialize);
    var result = _jsPortCreate.callSync(serialized);
    return _deserialize(result);
  }

  /**
   * Construct a [Proxy] to a new JavaScript map or list created defined via
   * Dart map or list.
   */
  factory Proxy._json(data) {
    if (_depth == 0) throw 'Cannot create Proxy out of scope.';
    return _convert(data);
  }

  static _convert(data) {
    // TODO(vsm): Can we make this more efficient?
    if (data is Map) {
      var result = _js('new Object()');
      for (var key in data.getKeys()) {
        var value = _convert(data[key]);
        result.noSuchMethod('set:$key', [value]);
      }
      return result;
    } else if (data is List) {
      var result = _js('new Array()');
      for (var i = 0; i < data.length; ++i) {
        var value = _convert(data[i]);
        result.noSuchMethod('set:$i', [value]);
      }
      return result;
    }
    return data;
  }

  Proxy._internal(this._port, this._id);

  // TODO(vsm): This is not required in Dartium, but
  // it is in Dart2JS.
  // Resolve whether this is needed.
  operator[](arg) => noSuchMethod('[]', [ arg ]);

  // Forward member accesses to the backing JavaScript object.
  noSuchMethod(method, args) {
    if (_depth == 0) throw 'Cannot access a JavaScript proxy out of scope.';
    var result = _port.callSync([_id, method, args.map(_serialize)]);
    switch (result[0]) {
      case 'return': return _deserialize(result[1]);
      case 'exception': throw _deserialize(result[1]);
      case 'none': throw new NoSuchMethodError(this, method, args);
      default: throw 'Invalid return value';
    }
  }
}

// A table to managed local Dart objects that are proxied in JavaScript.
// TODO(vsm): Combined Object and Function subtypes.
class _ProxiedReferenceTable<T> {
  // Debugging name.
  final String _name;

  // Generator for unique IDs.
  int _nextId;

  // Counter for invalidated IDs for debugging.
  int _deletedCount;

  // Table of IDs to Dart objects.
  final Map<String, T> _registry;

  // Port to handle and forward requests to the underlying Dart objects.
  // A remote proxy is uniquely identified by an ID and SendPortSync.
  final ReceivePortSync _port;

  // The set of IDs that are global.  These must be explicitly invalidated.
  final Set<String> _globalIds;

  // The stack of valid IDs.
  final List<String> _handleStack;

  // The stack of scopes, where each scope is represented by an index into the
  // handleStack.
  final List<int> _scopeIndices;

  // Enter a new scope.
  enterScope() {
    _scopeIndices.addLast(_handleStack.length);
  }

  // Invalidate non-global IDs created in the current scope and
  // restore to the previous scope.
  exitScope() {
    int start = _scopeIndices.removeLast();
    for (int i = start; i < _handleStack.length; ++i) {
      String key = _handleStack[i];
      if (!_globalIds.contains(key)) {
        _registry.remove(_handleStack[i]);
        _deletedCount++;
      }
    }
    _handleStack.removeRange(start, _handleStack.length - start);
  }

  // Convert an ID to a global.
  globalize(id) => _globalIds.add(id);

  // Invalidate an ID.
  invalidate(id) {
    var old = _registry[id];
    _globalIds.remove(id);
    _registry.remove(id);
    _deletedCount++;
    return old;
  }

  // Replace the object referenced by an ID.
  _replace(id, T x) {
    _registry[id] = x;
  }

  _ProxiedReferenceTable(this._name) :
      _nextId = 0,
      _deletedCount = 0,
      _registry = <T>{},
      _port = new ReceivePortSync(),
      _handleStack = new List<String>(),
      _scopeIndices = new List<int>(),
      _globalIds = new Set<String>();

  // Add a new object to the table and return a new ID for it.
  String add(T x) {
    if (_scopeIndices.length == 0) {
      throw "Must be inside scope to allocate.";
    }
    // TODO(vsm): Cache x and reuse id.
    final id = '$_name-${_nextId++}';
    _registry[id] = x;
    _handleStack.addLast(id);
    return id;
  }

  // Get an object by ID.
  T get(String id) {
    return _registry[id];
  }

  // Get the current number of objects kept alive by this table.
  get count => _registry.length;

  // Get the total number of IDs ever allocated.
  get total => count + _deletedCount;

  // Get a send port for this table.
  get sendPort => _port.toSendPort();
}

// A subtype for managing functions.
// TODO(vsm): Once operator call is implemented, this can be folded
// into the general table.
class _ProxiedFunctionTable extends _ProxiedReferenceTable<Function> {
  _ProxiedFunctionTable() : super('func-ref') {
    // Dispatch remote requests to the corresponding function.
    _port.receive((msg) {
      final id = msg[0];
      final args = msg[1].map(_deserialize);
      final f = _registry[id];
      switch (args.length) {
        case 0: return _serialize(f());
        case 1: return _serialize(f(args[0]));
        case 2: return _serialize(f(args[0], args[1]));
        case 3: return _serialize(f(args[0], args[1], args[2]));
        case 4: return _serialize(f(args[0], args[1], args[2], args[3]));
        default: throw 'Unsupported number of arguments.';
      }
    });
  }
}

// The singleton to manage proxied Dart functions.
_ProxiedFunctionTable __proxiedFunctionTable;
_ProxiedFunctionTable get _proxiedFunctionTable {
  if (__proxiedFunctionTable === null) {
    __proxiedFunctionTable = new _ProxiedFunctionTable();
  }
  return __proxiedFunctionTable;
}

// A subtype to manage non-Function Dart objects.
class _ProxiedObjectTable extends _ProxiedReferenceTable<Object> {
  _ProxiedObjectTable() : super('dart-ref') {
    _port.receive((msg) {
      // TODO(vsm): Support a mechanism to register a handler here.
      throw 'Invocation unsupported on Dart proxies';
    });
  }
}

// The singleton to manage proxied Dart objects.
_ProxiedObjectTable __proxiedObjectTable;
_ProxiedObjectTable get _proxiedObjectTable {
  if (__proxiedObjectTable === null) {
    __proxiedObjectTable = new _ProxiedObjectTable();
  }
  return __proxiedObjectTable;
}

/// End of proxy implementation.

// Dart serialization support.

// A Map to track remote functions and reserialize them properly.
// TODO(vsm): Once operator call is available, this table will be unnecessary.
// Remote functions will be represented by a Proxy object with a call method.
class _DeserializedFunctionTable {
  List data;
  _DeserializedFunctionTable() {
    data = [];
  }

  find(Function f) {
    for (var item in data) {
      if (f == item[0]) return item[1];
    }
    return null;
  }

  remove(Function f) {
    data = data.filter((item) => item[0] != f);
  }

  add(Function f, x) {
    data.add([f, x]);
  }
}

_DeserializedFunctionTable __deserializedFunctionTable = null;
get _deserializedFunctionTable {
  if (__deserializedFunctionTable == null) {
    __deserializedFunctionTable = new _DeserializedFunctionTable();
  }
  return __deserializedFunctionTable;
}

_serialize(var message) {
  if (message == null) {
    return null;  // Convert undefined to null.
  } else if (message is String ||
             message is num ||
             message is bool) {
    // Primitives are passed directly through.
    return message;
  } else if (message is SendPortSync) {
    // Non-proxied objects are serialized.
    return message;
  } else if (message is Element) {
    return [ 'domref', _serializeElement(message) ];
  } else if (message is Callback) {
    return message._serialized;
  } else if (message is Function) {
    var serialized = _deserializedFunctionTable.find(message);
    if (serialized != null) {
      // Remote cached function proxy.
      return serialized;
    } else {
      throw 'A function must be converted to a '
            'Callback before it can be serialized.';
    }
  } else if (message is Proxy) {
    // Remote object proxy.
    return [ 'objref', message._id, message._port ];
  } else {
    // Local object proxy.
    return [ 'objref',
             _proxiedObjectTable.add(message),
             _proxiedObjectTable.sendPort ];
  }
}

_deserialize(var message) {
  deserializeFunction(message) {
    var id = message[1];
    var port = message[2];
    if (port == _proxiedFunctionTable.sendPort) {
      // Local function.
      return _proxiedFunctionTable.get(id);
    } else {
      // Remote function.  Forward to its port.
      // TODO: Support varargs when there is support in the language.
      var f = ([arg0, arg1, arg2, arg3]) {
        var args;
        if (?arg3)
          args = [arg0, arg1, arg2, arg3];
        else if (?arg2)
          args = [arg0, arg1, arg2];
        else if (?arg1)
          args = [arg0, arg1];
        else if (?arg0)
          args = [arg0];
        else
          args = [];
        var message = [id, args.map(_serialize)];
        var result = port.callSync(message);
        return _deserialize(result);
      };

      // Cache the remote id and port.
      _deserializedFunctionTable.add(f, message);
      return f;
    }
  }

  deserializeObject(message) {
    var id = message[1];
    var port = message[2];
    if (port == _proxiedObjectTable.sendPort) {
      // Local object.
      return _proxiedObjectTable.get(id);
    } else {
      // Remote object.
      return new Proxy._internal(port, id);
    }
  }


  if (message == null) {
    return null;  // Convert undefined to null.
  } else if (message is String ||
             message is num ||
             message is bool) {
    // Primitives are passed directly through.
    return message;
  } else if (message is SendPortSync) {
    // Serialized type.
    return message;
  }
  var tag = message[0];
  switch (tag) {
    case 'funcref': return deserializeFunction(message);
    case 'objref': return deserializeObject(message);
    case 'domref': return _deserializeElement(message[1]);
  }
  throw 'Unsupported serialized data: $message';
}

// DOM element serialization.

int _localNextElementId = 0;

const _DART_ID = 'data-dart_id';

_serializeElement(Element e) {
  if (e.attributes.containsKey(_DART_ID)) return e.attributes[_DART_ID];
  // TODO(vsm): Use an isolate-specific id.
  var id = 'dart-${_localNextElementId++}';
  e.attributes[_DART_ID] = id;
  return id;
}

Element _deserializeElement(var id) {
  var list = queryAll('[$_DART_ID="$id"]');
  if (list.length > 1) throw 'Non unique ID: $id';
  if (list.length == 0) {
    throw 'Only elements attached to document can be serialized: $id';
  }
  return list[0];
}

/**
 * Debugging / profiling support.  Print the number of live handles in Dart
 * and JavaScript.
 */
void proxyDebug([String message = '']) {
  print('Proxy status $message:');
  var live = _proxiedObjectTable.count + _proxiedFunctionTable.count;
  var total = _proxiedObjectTable.total + _proxiedFunctionTable.total;
  print('  Dart objects Live : $live (out of $total ever allocated).');
  print('  ${_jsPortDebug.callSync([])}');
}
