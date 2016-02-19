// Copyright (c) 2016, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TOOD: Use binary search not indexOf to improve lookup performance

/// Memory efficent representation of the feature vectors and the aggregated
/// distribution statistics over the features
library smart.completion_model.feature_vector;

import 'dart:typed_data' as typd;
import 'dart:convert';

// Binary features
const IN_CLASS_NAME = "InClass";
const IN_METHOD_NAME = "InMethod";
const IN_FUNCTION_NAME = "InFunction";
const IN_FUNCTION_STATEMENT_NAME = "InFunctionStatement";
const IN_TRY_NAME = "InTry";
const IN_CATCH_NAME = "InCatch";
const IN_ICE_NAME = "InICE";
const IN_FORMAL_PARAM_NAME = "InFormalParam";
const IN_ASSIGN_NAME = "InAssignment";
const IN_COND_NAME = "InConditional";
const IN_FOREACH_NAME = "InForEachLoop";
const IN_FOR_NAME = "InForLoop";
const IN_WHILE_NAME = "InWhileLoop";
const IN_RETURN_NAME = "InReturnStatement";
const IN_STRING_INTERPOL_NAME = "InStringInterpolation";
const IN_STATIC_NAME = "InStaticMethod";
const IN_ASYNC_NAME = "InAsyncMethod";
const IN_SYNC_NAME = "InSyncMethod";
const IN_GENERATOR_NAME = "InGeneratorMethod";
const IN_ASSRT_NAME = "InAssertStatement";
const IN_AWAIT_NAME = "InAwaitExpression";
const IN_TEST_INVOCATION_NAME = "InTestMethodInvocation";
const IN_DESCRIBE_NAME = "InDescribeMethodInvocation";
const IN_MAIN_NAME = "InMainMethodDeclaration";
const IN_TEST_METHOD_NAME = "InTestMethodDeclaration";
const IN_DECLARATION_WITH_SET_NAME = "InDeclarationWithSet";
const IN_DECLARATION_WITH_GET_NAME = "InDeclarationWithGet";
const IN_DECLARATION_WITH_HAS_NAME = "InDeclarationWithHas";
const IN_DECLARATION_WITH_IS_NAME = "InDeclarationWithIs";

// Non-binary features
const ASSIGNMENT_LHS_STATIC = "assigmmentLHSStaticType";


/// Storage class for a statically defined set of features, either of binary or
/// string types
class FeatureVector {
  static const int VERSION = 0;

  List<bool> binaryFeatureValues;
  /// [binaryFeatureNames] is a constant list of the binary features. To add
  /// a feature add its name to this list via a constant
  /// and increment the VERSION above
  static const List<String> binaryFeatureNames = const <String>[
    IN_CLASS_NAME,
    IN_METHOD_NAME,
    IN_FUNCTION_NAME,
    IN_FUNCTION_STATEMENT_NAME,
    IN_TRY_NAME,
    IN_CATCH_NAME,
    IN_ICE_NAME,
    IN_FORMAL_PARAM_NAME,
    IN_ASSIGN_NAME,
    IN_COND_NAME,
    IN_FOREACH_NAME,
    IN_FOR_NAME,
    IN_WHILE_NAME,
    IN_RETURN_NAME,
    IN_STRING_INTERPOL_NAME,
    IN_STATIC_NAME,
    IN_ASYNC_NAME,
    IN_SYNC_NAME,
    IN_GENERATOR_NAME,
    IN_ASSRT_NAME,
    IN_AWAIT_NAME,
    IN_TEST_INVOCATION_NAME,
    IN_DESCRIBE_NAME,
    IN_MAIN_NAME,
    IN_TEST_METHOD_NAME,
    IN_DECLARATION_WITH_SET_NAME,
    IN_DECLARATION_WITH_GET_NAME,
    IN_DECLARATION_WITH_HAS_NAME,
    IN_DECLARATION_WITH_IS_NAME,
  ];



  Map<String, String> stringFeatureValues = {};

  static const List<String> stringFeatureNames = const <String>[
    ASSIGNMENT_LHS_STATIC
  ];

  FeatureVector() {
    binaryFeatureValues = new List(binaryFeatureNames.length);
  }

  static getFeatureNameFromIndex(int index) {
    if (index < binaryFeatureNames.length) {
      return binaryFeatureNames[index];
    } else {
      return stringFeatureNames[index - binaryFeatureNames.length];
    }
  }

  dynamic getValueFromIndex(int index) {
    if (index < binaryFeatureNames.length) {
      return binaryFeatureValues[index];
    } else {
      return stringFeatureValues[
        stringFeatureNames[index - binaryFeatureNames.length]
        ];
    }
  }

  /// Get the value for the feature or null if the feature isn't defined
  dynamic getValue(String name) {
    int featureIndex = binaryFeatureNames.indexOf(name);
    if (featureIndex != -1) return binaryFeatureValues[featureIndex];
    return stringFeatureValues[name];
  }

  // TODO: Replace this with a compound iterator to eliminate the
  // copy cost
  static Iterable<String> get allFeatureNames {
    List<String> accumulator = <String>[];
    accumulator.addAll(binaryFeatureNames);
    accumulator.addAll(stringFeatureNames);

    return accumulator;
  }

  static int get featureCount {
    return binaryFeatureNames.length + stringFeatureNames.length;
  }

  setValue(String name, dynamic value) {
    if (value is bool) {
      setBinaryValue(name, value);
    } else {
      setStringValue(name, "$value");
    }
  }

  setBinaryValue(String name, bool value) {
    int featureIndex = binaryFeatureNames.indexOf(name);

    if (featureIndex == -1)
      throw "Unknown feature";

    binaryFeatureValues[featureIndex] = value;
  }

  setStringValue(String name, String value) {
    stringFeatureValues[name] = value;
  }

  // Special properties, these are not features
  var _completion;
  var _targetType;

  // TODO: Use fully qualified type name?
  String get targetType => "$_targetType";
  set targetType(String s) { this._targetType = s; }

  String get completion => "$_completion";
  set completion(String s) { this._completion = s; }

  String toJsonString() {
    var obj = {
        "VERSION" : VERSION,
        "completion" : "$_completion",
        "targetType" : "$_targetType",
        "binaryFeatureValues" : binaryFeatureValues,
        "stringFeatureValues" : stringFeatureValues
      };
      return JSON.encode(obj);
  }

  FeatureVector fromJsonString(String json) {
    Map decoded = JSON.decode(json);
    if (decoded["VERSION"] != VERSION) {
      throw "Incompatible versions, source: $VERSION, json: ${decoded['VERSION']}";
    }

    FeatureVector vector = new FeatureVector();
    vector._completion = decoded['completion'];
    vector._targetType = decoded['targetType'];

    List<bool> decodedBinaryFeatureValues = decoded['binaryFeatureValues'];
    if (decodedBinaryFeatureValues.length != binaryFeatureNames.length)
      throw "Source data was of the wrong size";
    vector.binaryFeatureValues = decodedBinaryFeatureValues;

    for (String featureName in decoded['stringFeatureValues'].keys) {
      vector.stringFeatureValues[featureName]
        = decoded['stringFeatureValues'][featureName];
    }

    return vector;
  }
}

/// Memory efficent representation of counts over the feature vector structure
/// above. O(n * m) of these will be needed for n types and m completions
class FeatureValueDistribution {
  typd.Uint32List _binaryFeatureCount
    = new typd.Uint32List(FeatureVector.binaryFeatureNames.length * 2);

  Map<String, Map<String, int>> _featuresCountMap = {};

  incrementFeatureValueCount(String featureName, dynamic value) {
    var currentValue = getFeatureValueCount(featureName, value);
    if (currentValue == null) currentValue = 0;
    setFeatureValueCount(featureName, value, currentValue + 1);
  }

  int getTotalCountForFeatureIndex(int featureIndex) {
    if (featureIndex < FeatureVector.binaryFeatureNames.length) {
      int valueIndex = featureIndex * 2;
      int count = _binaryFeatureCount[valueIndex] // Value for false
        + _binaryFeatureCount[valueIndex+1];      // Value for true
      return count;
    } else {
      var featureValuesMap = _featuresCountMap[
        FeatureVector.stringFeatureNames[featureIndex - FeatureVector.binaryFeatureNames.length]];
      if (featureValuesMap == null) return 0;

      return featureValuesMap.values.fold(0, (a, b) => a + b);
    }
  }

  int getTotalCountForFeature(String featureName) {
    int featureIndex = FeatureVector.binaryFeatureNames.indexOf(featureName);
    if (featureIndex != -1) {
      int valueIndex = featureIndex * 2;
      int count = _binaryFeatureCount[valueIndex] // Value for false
        + _binaryFeatureCount[valueIndex+1];      // Value for true
      return count;
    }
    var featureValuesMap = _featuresCountMap[featureName];
    if (featureValuesMap == null) return 0;

    return featureValuesMap.values.fold(0, (a, b) => a + b);
  }


  int getValueCountForFeatureIndex(int featureIndex, dynamic value) {
    if (featureIndex < FeatureVector.binaryFeatureNames.length) {
      // This was a binary feature, return value for false, second for true
      int valueIndex = featureIndex * 2 + (value as bool ? 1 : 0);
      return _binaryFeatureCount[valueIndex];
    } else {
      var featureValuesMap = _featuresCountMap[
        FeatureVector.stringFeatureNames[featureIndex - FeatureVector.binaryFeatureNames.length]];
      if (featureValuesMap == null) return 0;

      return featureValuesMap["$value"];
    }
  }

  int getFeatureValueCount(String featureName, dynamic value) {
    int featureIndex = FeatureVector.binaryFeatureNames.indexOf(featureName);
    if (featureIndex != -1) {
      // This was a binary feature, return value for false, second for true
      int valueIndex = featureIndex * 2 + (value as bool ? 1 : 0);
      return _binaryFeatureCount[valueIndex];
    }
    var featureValuesMap = _featuresCountMap[featureName];
    if (featureValuesMap == null) return 0;

    return featureValuesMap["$value"];
  }

  setFeatureValueCount(String featureName, dynamic value, int count) {
    int featureIndex = FeatureVector.binaryFeatureNames.indexOf(featureName);
    if (featureIndex != -1) {
      _binaryFeatureCount[featureIndex * 2 + (value as bool ? 1 : 0)] = count;
      return;
    }

    _featuresCountMap.putIfAbsent(featureName, () => {})[value] = count;
  }

  // == Serialisation support methods ==
  // Binary features will have two values, each of 4 bytes
  int get _expectedFeatureCountByteCount  =>
    FeatureVector.binaryFeatureNames.length * 2 * 4;

  List<int> toStorageByteBlock() {
    typd.Uint8List byteBlockForFeatureCount =
      _binaryFeatureCount.buffer.asUint8List();

    if (byteBlockForFeatureCount.length !=
      _expectedFeatureCountByteCount)
      throw "ByteBlock length was unexpected";

    var mergedByteBlock = new List<int>();
    mergedByteBlock.addAll(byteBlockForFeatureCount);
    mergedByteBlock.addAll(UTF8.encode(JSON.encode(_featuresCountMap)));
    return mergedByteBlock;
  }

  FeatureValueDistribution.fromStorageBlock(List<int> block) {

    typd.Uint8List byteBlock = new typd.Uint8List.fromList(
      block.sublist(0, _expectedFeatureCountByteCount)
    );

    _binaryFeatureCount.setAll(0, byteBlock.buffer.asUint32List());

    // Read the feature blocks
    // binaryFeatureCount.setRange(0, _expectedFeatureCountByteCount, byteBlock.buffer.asUint32List());
    _featuresCountMap =
      JSON.decode(UTF8.decode(block.skip(_expectedFeatureCountByteCount).toList()));
  }

  // Default ctor creates an empty distribution
  FeatureValueDistribution() { }
}
