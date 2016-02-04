// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.completion_model.ast_features;

import 'package:analyzer/src/generated/ast.dart' as ast;
import '../analysis_utils/type_utils.dart';

/// Extract features for an ast construct with a target
Map extractFeaturesForTarget(ast.Expression realTarget, ast.AstNode node) {
  var bestType = realTarget.bestType;
  String targetTypeName = TypeUtils.qualifiedName(bestType.element);

  Map featuresAccumlator = extractFeaturesForNode(node);
  Map featuresFromTarget = {
    "TargetType": "$targetTypeName",
    "TargetName": "${realTarget}",
    "TargetRuntimeType": "${realTarget.runtimeType}",
  };
  featuresAccumlator.addAll(featuresFromTarget);
  return featuresAccumlator;
}

/// Extract features that apply to all AstNodes
Map extractFeaturesForNode(ast.AstNode node) {
  var features = {
    "InClass": _inClass(node),
    "InMethod": _inMethod(node),
    "InFunction": _inFunction(node),
    "InFunctionStatement": _inFunctionStatement(node),
    "InTry": _inTry(node),
    "InCatch": _inCatch(node),
    "InICE": _inICE(node),
    "InFormalParam": _inFormalParameter(node),
    "InAssignment": _inAssignment(node),
    "InConditional": _inConditionalExpression(node),
    "InForEachLoop": _inForEachLoop(node),
    "InForLoop": _inForLoop(node),
    "InWhileLoop": _inWhileLoop(node),
    "InReturnStatement": _inReturnStatement(node),
    "InStringInterpolation": _inStringInterpolation(node),
    "InStaticMethod": _inStaticMethod(node),
    "InAsyncMethod": _inAsyncMethod(node),
    "InSyncMethod": _inSyncMethod(node),
    "InGeneratorMethod": _inGeneratorMethod(node),
    "InAssertStatement": _inAssertStatement(node),
    "InAwaitExpression": _inAwaitExpression(node),
    "InTestMethodInvocation": _insideInvocationStartsWith(node, "test"),
    "InDescribeMethodInvocation": _insideInvocationStartsWith(node, "describe"),
    "InMainMethodDeclaration": _insideDeclarationStartsWith(node, "main"),
    "InTestMethodDeclaration": _insideDeclarationStartsWith(node, "test"),
    "InDeclarationWithSet": _insideDeclarationStartsWith(node, "set"),
    "InDeclarationWithGet": _insideDeclarationStartsWith(node, "get"),
    "InDeclarationWithHas": _insideDeclarationStartsWith(node, "has"),
    "InDeclarationWithIs": _insideDeclarationStartsWith(node, "is"),
    "assigmmentLHSStaticType": _assignmentType(node)
  };

  return features;
}

// Helper methods, once we're confident that these are sampling the
// right things they can be folded into more general implementations

bool _inClass(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.ClassDeclaration) != null;

bool _inMethod(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.MethodDeclaration) != null;

bool _inFunction(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.FunctionDeclaration) != null;

bool _inFunctionStatement(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.FunctionDeclarationStatement) != null;

bool _inICE(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.InstanceCreationExpression) != null;

bool _inStringInterpolation(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.StringInterpolation) != null;

bool _inTry(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.TryStatement) != null;

bool _inCatch(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.CatchClause) != null;

bool _inAssignment(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.AssignmentExpression) != null;

bool _inFormalParameter(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.FormalParameter) != null;

bool _inConditionalExpression(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.ConditionalExpression) != null;

bool _inForEachLoop(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.ForEachStatement) != null;

bool _inForLoop(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.ForStatement) != null;

bool _inWhileLoop(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.WhileStatement) != null;

bool _inReturnStatement(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.ReturnStatement) != null;

bool _inAssertStatement(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.AssertStatement) != null;

bool _inAwaitExpression(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.AwaitExpression) != null;

bool _insideInvocationStartsWith(ast.AstNode node, String name) =>
    node.getAncestor((p) => (p is ast.MethodInvocation) &&
            (p.methodName.name.startsWith(name))) !=
        null;

bool _insideDeclarationStartsWith(ast.AstNode node, String name) =>
    node.getAncestor((p) =>
            (p is ast.MethodDeclaration || p is ast.FunctionDeclaration) &&
                (p.name.name.startsWith(name))) !=
        null;

// bool _insideDeclarationContains(ast.AstNode node, String name) =>
//     node.getAncestor((p) =>
//             (p is ast.MethodDeclaration || p is ast.FunctionDeclaration) &&
//                 (p.name.name.contains(name))) !=
//         null;

bool _inStaticMethod(ast.AstNode node) => node.getAncestor((p) =>
        p is ast.MethodDeclaration && (p as ast.MethodDeclaration).isStatic) !=
    null;

bool _inAsyncMethod(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.MethodDeclaration &&
            (p as ast.MethodDeclaration).body.isAsynchronous) !=
        null;

bool _inSyncMethod(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.MethodDeclaration &&
            (p as ast.MethodDeclaration).body.isSynchronous) !=
        null;

bool _inGeneratorMethod(ast.AstNode node) =>
    node.getAncestor((p) => p is ast.MethodDeclaration &&
            (p as ast.MethodDeclaration).body.isGenerator) !=
        null;

String _assignmentType(ast.AstNode node) {
  if (!_inAssignment(node)) return "null";

  ast.AssignmentExpression assignment =
      node.getAncestor((p) => p is ast.AssignmentExpression);

  // We can only use the static type here to prevent accidentally cheating
  // and reading from the future.
  return assignment.leftHandSide.staticType.name;
}
