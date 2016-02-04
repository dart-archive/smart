// Copyright (c) 2016, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.discovery_model.feature_extractor;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:sintr_common/logging_utils.dart' as log;

import '../analysis_utils/analysis_utils.dart' as analysis_utils;

import '../analysis_utils/type_utils.dart';

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
  visitSimpleIdentifier(SimpleIdentifier node) {
    features.add({"TypeUsage": TypeUtils.qualifiedName(node.bestType.element)});
    return super.visitNode(node);
  }
}
