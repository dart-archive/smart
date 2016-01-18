// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.completion_model.feature_extractor;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:smart/logging_utils.dart' as log;

import 'analysis_utils.dart' as analysis_utils;
import 'ast_extractors.dart' as extractors;


// TODO(luekchurch): Refactor this so it shares an implementation with the
// completion_perf driver

class Analysis {
  Stopwatch sw;
  Analysis(String sdkPath) {
    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
  }

  List<Map> analyzeSpecificFile(String path) {
    log.trace("analyzeSpecificFile: $path");
    sw = new Stopwatch()..start();

    CompilationUnit compilationUnit = analysis_utils.setupAnalysis(path, sw);

    log.trace("setupAnalysis done: ${sw.elapsedMilliseconds}");

    FeatureExtractor extractor = new FeatureExtractor();
    compilationUnit.accept(extractor);
    log.trace("compilationUnit accepted: ${sw.elapsedMilliseconds}");
    analysis_utils.teardownStateAfterAnalysis();
    log.trace("State teardown complete: ${sw.elapsedMilliseconds}");

    return extractor.features;
  }
}

class FeatureExtractor extends GeneralizingAstVisitor {
  var features = [];

  @override
  visitPrefixedIdentifier(PrefixedIdentifier node) {
    Map featuresMap = extractors.featuresFromPrefixedIdentifier(node);
    features.add(featuresMap);
    return super.visitNode(node);
  }

  @override
  visitPropertyAccess(PropertyAccess node) {
    Map featuresMap = extractors.featuresFromPropertyAccess(node);
    features.add(featuresMap);
    return super.visitNode(node);
  }

  @override
  visitMethodInvocation(MethodInvocation node) {
    Map featuresMap = extractors.featuresFromMethodInvocation(node);
    features.add(featuresMap);
    return super.visitNode(node);
  }
}
