// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.exports;

import 'package:quiver/core.dart';

/**
 * The set of libraries and classes exported from Dart to JS, and proxy
 * classes for JS.
 *
 * This is a minimal AST needed to generate JavaScript for exports and to either
 * generate Dart for exports and proxy implementations when used in a
 * transformer, or dynamically implement proxies when used in Dartium.
 */
class JsElements {
  final Map<String, ExportedLibrary> exportedLibraries =
      <String, ExportedLibrary>{};
  final List<Proxy> proxies = <Proxy>[];

  /**
   * Returns an [ExportedLibrary] representing the library [name]. The existing
   * library object is returned if it exists, otherwise one is created on
   * demand.
   */
  ExportedLibrary getLibrary(String libraryName) {
    return exportedLibraries.putIfAbsent(libraryName,
        () => new ExportedLibrary(libraryName));
  }
}

/**
 * Represents a proxy class for a JavaScript object. Proxy classes are
 * those annotated with @JsProxy
 */
class Proxy {
  final String name;
  final bool isGlobal;
  final String constructor;

  Proxy(this.name, this.isGlobal, this.constructor);

  int get hashCode => hash3(name, isGlobal, constructor);

  bool operator ==(o) =>
      o is Proxy &&
      o.name == name &&
      o.isGlobal == isGlobal &&
      o.constructor == constructor;

  String toString() => 'proxy($name, $isGlobal, $constructor)';
}

/**
 * Base class for exported libraries, function, classes, variables, etc.
 */
abstract class ExportedElement<P extends ExportedElement> {
  final P parent;
  final String name;

  ExportedElement(this.name, this.parent);

  String getPath(String separator) =>
      name.replaceAll('.', separator);
}

class ExportedLibrary extends ExportedElement<ExportedLibrary> {
  final Map<String, ExportedElement> declarations = <String, ExportedElement>{};

  ExportedLibrary(String name) : super(name, null);

  String toString() => 'ExportedLibrary(name: $name, '
      'declarations: $declarations)';
}

class ExportedClass extends ExportedElement<ExportedLibrary> {
  final Map<String, ExportedElement> children = <String, ExportedElement>{};

  ExportedClass(String name, ExportedLibrary parent) : super(name, parent);

  String getPath(String separator) =>
      [parent.getPath(separator), name.replaceAll('.', separator)]
          .join(separator);

  String toString() => 'ExportedClass($name)';
}

/**
 * Represents a Dart type.
 */
class DartType {
  final String name;
  DartType(this.name);

  String toString() => name;
}

/**
 * Enum that classifies the kind of a parameter, [REQUIRED], [POSITIONAL], or
 * [NAMED].
 */
class ParameterKind {
  static const REQUIRED = const ParameterKind(0, 'REQUIRED');
  static const POSITIONAL = const ParameterKind(1, 'POSITIONAL');
  static const NAMED = const ParameterKind(2, 'NAMED');

  final int _value;
  final String _name;

  const ParameterKind(this._value, this._name);

  String toString() => _name;
}

/**
 * A function, method or constructor parameter.
 */
class ExportedParameter {
  final String name;
  final ParameterKind kind;
  final DartType type;

  ExportedParameter(this.name, this.kind, this.type);

  String toString() => '{$type $name}';
}

class ExportedConstructor extends ExportedElement<ExportedClass> {
  final List<ExportedParameter> parameters;

  ExportedConstructor(String name, ExportedClass parent, this.parameters)
      : super(name, parent);
}

class ExportedMethod extends ExportedElement<ExportedClass> {
  final bool isStatic;
  final List<ExportedParameter> parameters;

  ExportedMethod(String name, ExportedClass parent, this.parameters,
      {this.isStatic : false})
      : super(name, parent);

  String toString() => 'ExportedMethod($name $parameters)';
}

/**
 * Represents a field or getter/setter.
 */
class ExportedProperty extends ExportedElement<ExportedClass> {
  final bool isStatic;
  bool hasGetter;
  bool hasSetter;

  ExportedProperty(String name, ExportedClass parent,
      {this.hasGetter : false, this.hasSetter : false, this.isStatic: false})
      : super(name, parent);

  String toString() => 'ExportedProperty($name)';
}

class ExportedTopLevelVariable extends ExportedElement<ExportedLibrary> {
  ExportedTopLevelVariable(String name, ExportedLibrary parent)
      : super(name, parent);
}

class ExportedFunction extends ExportedElement<ExportedLibrary> {
  ExportedFunction(String name, ExportedLibrary parent) : super(name, parent);
}

