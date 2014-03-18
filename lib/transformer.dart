
import 'dart:async';
import 'dart:collection';

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' hide Logger;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/java_core.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:analyzer/src/generated/source_io.dart';
import 'package:barback/barback.dart';
import 'package:code_transformers/resolver.dart';

import 'package:source_maps/span.dart' show Location;

//class ExportTransformerGroup implements TransformerGroup {
//
//  ExportTransformerGroup.asPlugin(BarbackSettings settings) {
//    print(settings);
//  }
//
//  @override
//  Iterable<Iterable> get phases => [
//    [new FindExports()]
//  ];
//}


class FindExports extends Transformer {
  static final _isPrimaryPattern = new RegExp(r'^?:(web|test|bin)/');

  final Resolvers resolvers;
  final List<String> entryPoints;

  FindExports.asPlugin(BarbackSettings settings)
      : this(_getEntryPoints(settings), new Resolvers(dartSdkDirectory));

  FindExports(this.entryPoints, this.resolvers) {
    print("FindExports!");
  }

  Future<bool> isPrimary(Asset input) {
    var id = input.id;
    return new Future.value((id.extension == '.dart')
        && ((entryPoints == null && _isPrimaryPattern.hasMatch(id.path))
            || entryPoints.contains(id.path)));
  }

  @override
  Future apply(Transform transform) {
    var input = transform.primaryInput;
    print("apply: $input");
    return resolvers.get(transform).then((resolver) {
      print("got resolver");
      var exportedLibraries = <String>[];
      LibraryElement entryLibrary = resolver.getLibrary(input.id);
      print("entryLibrary: $entryLibrary");

      var exportLib = resolver.getLibraryByName('js.export_to_js');
      print("exportLib: $exportLib");
      var exportClass = exportLib.getType('Export');

      var exportFinder = new ExportFinder(exportClass);
      for (LibraryElement library in resolver.libraries) {
        library.accept(exportFinder);
      }

      var sb = new StringBuffer();
      exportFinder.exports.write(sb);

      var exportId = input.id.addExtension('.exports.js');
      var exportAsset = new Asset.fromString(exportId, sb.toString());
      transform.addOutput(exportAsset);

//      var fileSpan = edit.file.span(0);
//      Location fileEnd = fileSpan.end;

      var edit = resolver.createTextEditTransaction(entryLibrary);
      edit.edit(0, 0, '// a new line\n');
      var printer = edit.commit();
      printer.build(input.id.path);
      print("new source: ${printer.text}");

      var newEntryPoint = new Asset.fromString(input, printer.text);
      transform.addOutput(newEntryPoint);
    });
  }
}

class ExportFinder extends RecursiveElementVisitor {
  final ClassElement exportClass;
  final StringBuffer output = new StringBuffer();
  final Exports exports = new Exports();

  ExportFinder(this.exportClass);

  bool isExported(Element e) =>
      e.metadata.any((m) =>
          (m.element.kind == ElementKind.CONSTRUCTOR &&
          m.element.enclosingElement == exportClass));

  @override
  visitLibraryElement(LibraryElement element) {
    if (isExported(element)) {
      exports.addLibrary(element);
    }
    super.visitLibraryElement(element);
  }

  @override
  visitClassElement(ClassElement element) {
    if (isExported(element) || isExported(element.library)) {
      exports.addClass(element);
    }
    super.visitClassElement(element);
  }

  @override
  visitMethodElement(MethodElement element) {
    if (isExported(element) || isExported(element.enclosingElement)
        || isExported(element.library)) {
      exports.addMethod(element);
    }
    super.visitMethodElement(element);
  }

  visitFieldElement(VariableElement element) {
    super.visitFieldElement(element);
  }
}

class Exports {
  final libraries = <String, ExportedLibrary>{};
  final classes = <String, ExportedClass>{};

  Exports();

  ExportedLibrary addLibrary(LibraryElement element) {
    String libraryName = element.name;
    // The analyzer is adding '.dart' to library names, so we remove it.
    if (libraryName.endsWith('.dart')) {
      libraryName = libraryName.substring(0, libraryName.length - 5);
    }
    var parts = libraryName.split('.');
    print("parts: $parts");
    if (parts.length > 1) {
      var leafName = parts.last;
      var parent = null;
      for (var name in parts.sublist(0, parts.length - 1)) {
        parent = libraries.putIfAbsent(name, () => new ExportedLibrary(name));
      }
      return parent.children.putIfAbsent(leafName,
          () => new ExportedLibrary(leafName, parent: parent)..element = element);
    } else {
      print("adding top-level library: $libraryName");
      return libraries.putIfAbsent(libraryName,
          () => new ExportedLibrary(libraryName)..element = element);
    }
  }

  ExportedClass addClass(ClassElement element) {
    if (classes.containsKey(element.name)) {
      return classes[element.name];
    }
    var libraryELement = element.library;
    var exportedLibrary = addLibrary(libraryELement);
    return exportedLibrary.children.putIfAbsent(element.name,
        () => new ExportedClass(element, exportedLibrary));
  }

  ExportedMethod addMethod(MethodElement element) {
    var exportedClass = addClass(element.enclosingElement);
    return exportedClass.children.putIfAbsent(element.name,
      () => new ExportedMethod(element, exportedClass));
  }

  write(StringSink sink) {
    sink.write('dart = {};\n');
    for (var library in libraries.values) {
      library.write(sink);
    }
  }
}

abstract class ExportedElement {
  write(StringSink sink);
}

class ExportedLibrary implements ExportedElement {
  final String name;
  final ExportedLibrary parent;
  final Map<String, ExportedElement> children = <String, ExportedElement>{};
  LibraryElement element;

  ExportedLibrary(this.name, {this.parent});

  Iterable<String> get path => parent == null
      ? ['dart', name]
      : (new List.from(parent.path)..add(name));

  write(StringSink sink) {
    print("writing library $name $path $parent");
    sink
        ..writeAll(path, '.')
        ..write(' = {};\n');
    for (var child in children.values){
      child.write(sink);
    }
  }

  String toString() => "library name";
}

class ExportedClass implements ExportedElement {
  final ExportedLibrary parent;
  final ClassElement element;
  final Map<String, ExportedElement> children = <String, ExportedElement>{};

  ExportedClass(this.element, this.parent);

  Iterable<String> get path => new List.from(parent.path)..add(element.name);

  write(StringSink sink) {
    var pathString = path.join('.');
    print("exporting class $pathString ${element.name}");
    sink
      ..write('$pathString = function() {};\n')
      ..write('$pathString.prototype = {\n');
    for (var child in children.values) {
      child.write(sink);
    }
    sink.write('};\n');
  }
}

class ExportedMethod implements ExportedElement {
  final ExportedClass parent;
  final MethodElement element;

  ExportedMethod(this.element, this.parent);

  write(StringSink sink) {
    sink
      ..write('  ${element.name}: function() {};\n');
  }

}

class ExportedField implements ExportedElement {
  final ExportedClass parent;
  final FieldElement element;

  ExportedField(this.element, this.parent);

  write(StringSink sink) {
    var parentPath = parent.path.join('.');
    sink
      ..write(
'''Object.defineProperty($parentPath, "${element.name}", {
  get: function() {}
''');
  }

}

List<String> _getEntryPoints(BarbackSettings settings) {
  var value = settings.configuration['entry_points'];
  if (value == null) return null;
  var entryPoints = <String>[];
  if (value is List) {
    entryPoints.addAll(value);
  } else if (value is String) {
    entryPoints = [value];
  } else {
    print('Invalid value for "entry_points" in the polymer transformer.');
  }
  return entryPoints;
}

var exportJsHeader = '''
dart = dart || {};
// a convenience function for parsing string namespaces and
// automatically generating nested namespaces
function createLibrary(path) {
  var parts = path.split('.');
  var parent = dart;
  var length = parts.length;
  for (var i = 0; i < length; i++) {
    if (!parent.hasOwnProperty(parts[i])) {
      parent[parts[i]] = {};
    }
    parent = parent[parts[i]];
  }
  return parent;
}
''';


class PropertyIterable<T> extends IterableBase<T> {
  final T object;
  final next;

  PropertyIterable(T this.object, T this.next(T o));

  @override
  Iterator<T> get iterator => new PropertyIterator(object, next);
}

class PropertyIterator<T> implements Iterator<T> {
  final next;
  T object;
  bool started = false;

  PropertyIterator(T this.object, T this.next(T o));

  @override
  T get current => started ? object : null;

  @override
  bool moveNext() {
    if (object == null) return false;
    object = next(object);
    return object != null;
  }
}


//class EntryPointTransformer extends AstCloner {
//
//
//}