// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Support library for managing the state of analysis during feature
/// extraction and modelling
library smart.completion_models.analysis_utils;

import 'dart:io' as io;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:analyzer/src/generated/source_io.dart';

AnalysisContext context;
Source source;
String lastPubspecPath;

// TODO(lukechurch): Factor this into the logging library
const DIAGNOSTICS_ENABLED = false;
DartSdk sdk = DirectoryBasedDartSdk.defaultSdk;

CompilationUnit setupAnalysis(String path, Stopwatch sw) {
  if (context == null) context =
      AnalysisEngine.instance.createAnalysisContext();

  if (source != null) teardownStateAfterAnalysis();

  // Walk back up the path until we find the pubspec yaml path
  io.Directory d = new io.Directory.fromUri(new Uri.file(path));

  io.Directory packageD = null;
  while (d.parent.path != d.path) {
    if (new io.File(d.path + "/pubspec.yaml").existsSync()) {
      packageD = new io.Directory(d.path + "/packages");
      if (packageD.existsSync()) {
        break;
      } else packageD = null;
    }
    d = d.parent;
  }

  if (DIAGNOSTICS_ENABLED) print(
      "PERF: ${sw.elapsedMilliseconds} : pubspec located");

  if (packageD != null) {
    if (packageD.path != lastPubspecPath) {
      context.dispose();
      context = AnalysisEngine.instance.createAnalysisContext();
      lastPubspecPath = packageD.path;
      if (DIAGNOSTICS_ENABLED) print(
          "${new DateTime.now()} New pubspec path: $lastPubspecPath");
    }

    JavaFile packageDJavaFile = new JavaFile(packageD.path);
    List<JavaFile> lst = new List<JavaFile>();
    lst.add(packageDJavaFile);

    context.sourceFactory = new SourceFactory([
      new DartUriResolver(sdk),
      new FileUriResolver(),
      new PackageUriResolver(lst)
    ]);
  } else {
    context.dispose();
    context = AnalysisEngine.instance.createAnalysisContext();
    context.sourceFactory =
        new SourceFactory([new DartUriResolver(sdk), new FileUriResolver(),]);
  }

  AnalysisOptionsImpl options =
      new AnalysisOptionsImpl.from(context.analysisOptions);
  options.cacheSize = 512;
  context.analysisOptions = options;
  source = new FileBasedSource(
      new JavaFile(path));

  ChangeSet changeSet = new ChangeSet();
  changeSet.addedSource(source);
  context.applyChanges(changeSet);

  if (DIAGNOSTICS_ENABLED) print(
      "PERF: ${sw.elapsedMilliseconds} : changes applied");

  LibraryElement libElement = context.computeLibraryElement(source);
  CompilationUnit resolvedUnit =
      context.resolveCompilationUnit(source, libElement);

  if (DIAGNOSTICS_ENABLED) print(
      "PERF: ${sw.elapsedMilliseconds} : resolution complete");

  return resolvedUnit;
}

teardownStateAfterAnalysis() {
  if (source == null) return;

  ChangeSet changeSet = new ChangeSet();
  changeSet.removedSource(source);
  context.applyChanges(changeSet);
}
