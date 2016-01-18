// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.completion_models.ast_extractors;

import 'package:analyzer/src/generated/ast.dart' as ast;

import 'ast_features.dart';

const COMPLETION_RESULT = "**Completion";

Map featuresFromPrefixedIdentifier(ast.PrefixedIdentifier node) {
  // TODO(lukechurch): Address the below from the completion logic:
  // "some PrefixedIdentifier nodes are transformed into
  // ConstructorName nodes during the resolution process."

  var realTarget = node.prefix;
  var completion = node.identifier;

  if (realTarget != null) {
    var invocation = extractFeaturesForTarget(realTarget, node);
    invocation.putIfAbsent(COMPLETION_RESULT, () => "$completion");
    return invocation;
  }

  return null;
}

Map featuresFromPropertyAccess(ast.PropertyAccess node) {
  var realTarget = node.realTarget;
  var completion = node.propertyName;

  if (realTarget != null) {
    var invocation = extractFeaturesForTarget(realTarget, node);
    invocation.putIfAbsent(COMPLETION_RESULT, () => "$completion");
    return invocation;
  }

  return null;
}

Map featuresFromMethodInvocation(ast.MethodInvocation node) {
  var realTarget = node.realTarget;
  var completion = node.methodName;

  if (realTarget != null) {
    var invocation = extractFeaturesForTarget(realTarget, node);
    invocation.putIfAbsent(COMPLETION_RESULT, () => "$completion");
    return invocation;
  }

  return null;
}
