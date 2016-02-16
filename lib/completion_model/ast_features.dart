// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.completion_model.ast_features;

import 'package:analyzer/src/generated/ast.dart' as ast;
import '../analysis_utils/type_utils.dart';
import 'feature_vector.dart' as features;

/// Extract features for an ast construct with a target
features.FeatureVector extractFeaturesForTarget(ast.Expression realTarget, ast.AstNode node) {
  var vector = new features.FeatureVector();

  var bestType = realTarget.bestType;
  vector.targetType = TypeUtils.qualifiedName(bestType.element);
  _extractFeaturesForNode(node, vector);

  return vector;
}

/// Extract features that apply to all AstNodes
_extractFeaturesForNode(ast.AstNode node, features.FeatureVector vector) {
  vector.setValue(features.IN_CLASS_NAME, _inClass(node));
  vector.setValue(features.IN_METHOD_NAME, _inMethod(node));
  vector.setValue(features.IN_FUNCTION_NAME, _inFunction(node));
  vector.setValue(features.IN_FUNCTION_STATEMENT_NAME, _inFunctionStatement(node));
  vector.setValue(features.IN_TRY_NAME, _inTry(node));
  vector.setValue(features.IN_CATCH_NAME, _inCatch(node));
  vector.setValue(features.IN_ICE_NAME, _inICE(node));
  vector.setValue(features.IN_FORMAL_PARAM_NAME, _inFormalParameter(node));
  vector.setValue(features.IN_ASSIGN_NAME, _inAssignment(node));
  vector.setValue(features.IN_COND_NAME, _inConditionalExpression(node));
  vector.setValue(features.IN_FOREACH_NAME, _inForEachLoop(node));
  vector.setValue(features.IN_FOR_NAME, _inForLoop(node));
  vector.setValue(features.IN_WHILE_NAME, _inWhileLoop(node));
  vector.setValue(features.IN_RETURN_NAME, _inReturnStatement(node));
  vector.setValue(features.IN_STRING_INTERPOL_NAME, _inStringInterpolation(node));
  vector.setValue(features.IN_STATIC_NAME, _inStaticMethod(node));
  vector.setValue(features.IN_ASYNC_NAME, _inAsyncMethod(node));
  vector.setValue(features.IN_SYNC_NAME, _inSyncMethod(node));
  vector.setValue(features.IN_GENERATOR_NAME, _inGeneratorMethod(node));
  vector.setValue(features.IN_ASSRT_NAME, _inAssertStatement(node));
  vector.setValue(features.IN_AWAIT_NAME, _inAwaitExpression(node));
  vector.setValue(features.IN_TEST_INVOCATION_NAME, _insideInvocationStartsWith(node, "test"));
  vector.setValue(features.IN_DESCRIBE_NAME, _insideInvocationStartsWith(node, "describe"));
  vector.setValue(features.IN_MAIN_NAME, _insideDeclarationStartsWith(node, "main"));
  vector.setValue(features.IN_TEST_METHOD_NAME, _insideDeclarationStartsWith(node, "test"));
  vector.setValue(features.IN_DECLARATION_WITH_SET_NAME, _insideDeclarationStartsWith(node, "set"));
  vector.setValue(features.IN_DECLARATION_WITH_GET_NAME, _insideDeclarationStartsWith(node, "get"));
  vector.setValue(features.IN_DECLARATION_WITH_HAS_NAME, _insideDeclarationStartsWith(node, "has"));
  vector.setValue(features.IN_DECLARATION_WITH_IS_NAME, _insideDeclarationStartsWith(node, "is"));
  vector.setValue(features.ASSIGNMENT_LHS_STATIC, _assignmentType(node));

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
