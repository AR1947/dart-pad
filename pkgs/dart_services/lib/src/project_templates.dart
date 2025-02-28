// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Sets of project template directory paths.
class ProjectTemplates {
  ProjectTemplates._({
    required this.dartPath,
    required this.flutterPath,
    required this.firebasePath,
    required this.firebaseDeprecatedPath,
    required this.summaryFilePath,
  });

  factory ProjectTemplates() {
    final basePath = _baseTemplateProject();
    final summaryFilePath = path.join(
      'artifacts',
      'flutter_web.dill',
    );
    return ProjectTemplates._(
      dartPath: path.join(basePath, 'dart_project'),
      flutterPath: path.join(basePath, 'flutter_project'),
      firebasePath: path.join(basePath, 'firebase_project'),
      firebaseDeprecatedPath:
          path.join(basePath, 'firebase_deprecated_project'),
      summaryFilePath: summaryFilePath,
    );
  }

  /// The path to the plain Dart project template path.
  final String dartPath;

  /// The path to the Flutter (without Firebase) project template path.
  final String flutterPath;

  /// The path to the Firebase (with Flutter) project template path.
  final String firebasePath;

  /// The path to the deprecated Firebase (with Flutter) project template path.
  final String firebaseDeprecatedPath;

  /// The path to summary files.
  final String summaryFilePath;

  static ProjectTemplates projectTemplates = ProjectTemplates();

  static String _baseTemplateProject() =>
      path.join(Directory.current.path, 'project_templates');
}

/// The set of Firebase packages which are used in both deprecated Firebase
/// projects and "pure Dart" Flutterfire projects.
const Set<String> coreFirebasePackages = {
  'firebase_core',
};

/// The set of Firebase packages which can be registered in the generated
/// registrant file. Theoretically this should be _all_ plugins, but there
/// are bugs. See https://github.com/dart-lang/dart-pad/issues/2033 and
/// https://github.com/FirebaseExtended/flutterfire/issues/3962.
const Set<String> registerableFirebasePackages = {
  'cloud_firestore',
  'firebase_auth',
};

/// The set of Firebase packages which indicate that Firebase is being used.
const Set<String> firebasePackages = {
  ...coreFirebasePackages,
  ...registerableFirebasePackages,
};

/// The set of supported Flutter-oriented packages.
const Set<String> supportedFlutterPackages = {
  'animations',
  'creator',
  'firebase_analytics',
  'firebase_database',
  'firebase_messaging',
  'firebase_storage',
  'flame',
  'flame_fire_atlas',
  'flame_forge2d',
  'flame_splash_screen',
  'flame_tiled',
  'flutter_adaptive_scaffold',
  'flutter_bloc',
  'flutter_hooks',
  'flutter_lints',
  'flutter_map',
  'flutter_processing',
  'flutter_riverpod',
  'flutter_svg',
  'go_router',
  'google_fonts',
  'hooks_riverpod',
  'provider',
  'riverpod_navigator',
  'shared_preferences',
  'video_player',
};

/// The set of packages which indicate that Flutter Web is being used.
const Set<String> _packagesIndicatingFlutter = {
  'flutter',
  'flutter_test',
  ...supportedFlutterPackages,
  ...firebasePackages,
};

/// The set of basic Dart (non-Flutter) packages which can be directly imported
/// into a script.
const Set<String> supportedBasicDartPackages = {
  'basics',
  'bloc',
  'characters',
  'collection',
  'cross_file',
  'dartz',
  'english_words',
  'equatable',
  'fast_immutable_collections',
  'http',
  'intl',
  'js',
  'lints',
  'matcher',
  'meta',
  'path',
  'petitparser',
  'quiver',
  'riverpod',
  'rohd',
  'rohd_vf',
  'rxdart',
  'timezone',
  'tuple',
  'vector_math',
  'yaml',
  'yaml_edit',
};

/// The set of all packages whose support in DartPad is deprecated.
const Set<String> _deprecatedPackages = {
  'tuple',
};

/// A set of all allowed `dart:` imports. Currently includes non-VM libraries
/// listed as the [doc](https://api.dart.dev/stable/index.html) categories.
const Set<String> _allowedDartImports = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:developer',
  'dart:math',
  'dart:typed_data',
  'dart:html',
  'dart:indexed_db',
  'dart:js',
  'dart:js_util',
  'dart:svg',
  'dart:web_audio',
  'dart:web_gl',
  'dart:ui',
};

/// Returns whether [imports] denote use of Flutter Web.
bool usesFlutterWeb(Iterable<ImportDirective> imports) =>
    imports.any((import) => isFlutterWebImport(import.uri.stringValue));

/// Whether the [importString] represents an import
/// that denotes use of Flutter Web.
@visibleForTesting
bool isFlutterWebImport(String? importString) {
  if (importString == null) return false;
  if (importString == 'dart:ui') return true;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null &&
      _packagesIndicatingFlutter.contains(packageName);
}

/// Returns whether [imports] denote use of Firebase.
bool usesFirebase(Iterable<ImportDirective> imports) =>
    imports.any((import) => isFirebaseImport(import.uri.stringValue));

/// Whether the [importString] represents an import
/// that denotes use of a Firebase package.
@visibleForTesting
bool isFirebaseImport(String? importString) {
  if (importString == null) return false;

  final packageName = _packageNameFromPackageUri(importString);
  return packageName != null && firebasePackages.contains(packageName);
}

/// If [uriString] represents a 'package:' URI, then returns the package name;
/// otherwise `null`.
String? _packageNameFromPackageUri(String uriString) {
  final uri = Uri.tryParse(uriString);
  if (uri == null) return null;
  if (uri.scheme != 'package') return null;
  if (uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.first;
}

/// Goes through imports list and returns list of unsupported imports.
/// Optional [sourceFiles] contains a list of the source filenames
/// which are all part of this overall sources file set (these are to
/// be allowed).
///
/// Note: The filenames in [sourceFiles] were sanitized of any
/// 'package:'/etc syntax as the file set arrives from the endpoint, and
/// before being passed to [getUnsupportedImports]. This is done so
/// the list can't be used to bypass unsupported imports.
List<ImportDirective> getUnsupportedImports(
  List<ImportDirective> imports, {
  Set<String>? sourceFiles,
}) {
  return imports
      .where((import) => isUnsupportedImport(import.uri.stringValue,
          sourceFiles: sourceFiles ?? const {}))
      .toList(growable: false);
}

/// Whether the [importString] represents an import
/// that is unsupported.
@visibleForTesting
bool isUnsupportedImport(
  String? importString, {
  Set<String> sourceFiles = const {},
}) {
  if (importString == null || importString.isEmpty) {
    return false;
  }
  // All non-VM 'dart:' imports are ok.
  if (importString.startsWith('dart:')) {
    return !_allowedDartImports.contains(importString);
  }
  // Filenames from within this compilation files={} sources file set
  // are OK. (These filenames have been sanitized to prevent 'package:'
  // (and other) prefixes, so the a filename cannot be used to bypass
  // import restrictions (see comment above)).
  if (sourceFiles.contains(importString)) {
    return false;
  }

  final uri = Uri.tryParse(importString);
  if (uri == null) return false;

  // We allow a specific set of package imports.
  if (uri.scheme == 'package') {
    if (uri.pathSegments.isEmpty) return true;
    final package = uri.pathSegments.first;
    return !isSupportedPackage(package);
  }

  // Don't allow file imports.
  return true;
}

bool isSupportedPackage(String package) =>
    _packagesIndicatingFlutter.contains(package) ||
    supportedBasicDartPackages.contains(package);

/// If the specified [package] is deprecated in DartPad and
/// slated to be removed in a future update.
bool isDeprecatedPackage(String package) =>
    _deprecatedPackages.contains(package);
