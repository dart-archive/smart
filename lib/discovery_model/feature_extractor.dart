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
  //
  // @override
  // visitMethodInvocation(MethodInvocation mi) {
  //   print("MI: $mi RealTarget: ${mi.realTarget} @ ${mi.offset}");
  //
  //   _HaltingExtractor previous = new _HaltingExtractor(mi.offset);
  //   mi.root.accept(previous);
  //   var previousAll = previous.computeDerviedLists();
  //   var filtered = previous.getForTargetName(previousAll, "${mi.realTarget}");
  //   var completions = previous.getCompletionsFromAstNodes(filtered);
  //
  //   print("Completions: ${completions.reversed}");
  //
  //   // print ("");
  //   // for (MethodInvocation previous in previous.mis.reversed) {
  //   //   print ("- previousMI $previous ${previous.offset}");
  //   //   print ("- target: ${previous.target}");
  //   // }
  //   // print("");
  //   // for (SimpleIdentifier previous in previous.sis.reversed) {
  //   //   print ("- previousSI $previous ${previous.offset}");
  //   // }
  //   // print("");
  //
  //   // dumpASTChain(mi);
  //   return super.visitNode(mi);
  // }
  //
  // dumpASTChain(AstNode node) {
  //   print("= Node parental tree =");
  //   StringBuffer sb = new StringBuffer();
  //   while (node != null) {
  //     print("$sb ${node.runtimeType} @ ${node.offset}");
  //     node = node.parent;
  //     sb.write(" ");
  //   }
  //   print("");
  // }
}

/// An extractor that stops at a given offset
class _HaltingExtractor extends GeneralizingAstVisitor {
  List<SimpleIdentifier> sis = [];
  List<MethodInvocation> mis = [];
  List<PropertyAccess> pas = [];
  List<PrefixedIdentifier> pis = [];

  List<AstNode> all;

  int haltingOffset;

  _HaltingExtractor(this.haltingOffset);

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.offset >= haltingOffset) return;
    sis.add(node);
    super.visitNode(node);
  }

  @override
  visitMethodInvocation(MethodInvocation mi) {
    if (mi.offset >= haltingOffset) return;
    mis.add(mi);
    super.visitNode(mi);
  }

  @override
  visitPropertyAccess(PropertyAccess pa) {
    if (pa.offset >= haltingOffset) return;
    pas.add(pa);
    super.visitNode(pa);
  }

  @override
  visitPrefixedIdentifier(PrefixedIdentifier pi) {
    if (pi.offset >= haltingOffset) return;
    pis.add(pi);
    super.visitNode(pi);
  }

  List<AstNode> computeDerviedLists() {
    all = [];
    all..addAll(sis)..addAll(mis)..addAll(pas)..addAll(pis);
    all.sort((a, b) => a.offset.compareTo(b.offset));
    return all;
  }

  List<AstNode> getForTargetName(Iterable<AstNode> nodes, String name) {
    List<AstNode> ret = [];
    for (AstNode node in nodes) {
      if (node is PrefixedIdentifier && "${node.prefix}" == name) {
        ret.add(node);
      } else if (node is PropertyAccess && "${node.realTarget}" == name) {
        ret.add(node);
      } else if (node is MethodInvocation && "${node.realTarget}" == name) {
        ret.add(node);
      }
    }
    return ret;
  }

  List<AstNode> getForTargetType(Iterable<AstNode> nodes, String typeName) {
    List<AstNode> ret = [];
    for (AstNode node in nodes) {
      if (node is PrefixedIdentifier && "${node.prefix.bestType}" == typeName) {
        ret.add(node);
      } else if (node is PropertyAccess &&
          "${node.realTarget.bestType}" == typeName) {
        ret.add(node);
      } else if (node is MethodInvocation &&
          "${node.realTarget.bestType}" == typeName) {
        ret.add(node);
      }
    }
    return ret;
  }

  List<String> getCompletionsFromAstNodes(Iterable<AstNode> nodes) {
    List<String> completions = [];
    for (AstNode node in nodes) {
      if (node is PrefixedIdentifier) {
        completions.add("${node.identifier}");
      } else if (node is PropertyAccess) {
        completions.add("${node.propertyName}");
      } else if (node is MethodInvocation) {
        completions.add("${node.methodName}");
      }
    }
    return completions;
  }
}
