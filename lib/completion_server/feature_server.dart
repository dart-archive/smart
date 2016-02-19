// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Adds a server component that abstracts over the source of the feature
/// storage. Currently only reading and writing the features from disk
/// storage is supported.
library smart.completion_server.feature_server;

import 'dart:convert';
import 'dart:io' as io;

import 'package:smart/completion_model/feature_vector.dart';

import 'package:crypto/crypto.dart' as crypto;

class FeatureServer {
  Map<String, Map<String, FeatureValueDistribution>>
    _targetType_completion_featureValues =
      <String, Map<String, FeatureValueDistribution>>{};

  // TODO: Consider storing this in the distribution above to
  // decrease the memory cost of the second map
  Map<String, Map<String, int>> _completionsCount =
    <String, Map<String, int>>{};

  // Empty Model
  FeatureServer() {}

  Map<String, int> getCompletionCount(String targetType)
    => _completionsCount[targetType];

  Map<String, FeatureValueDistribution>
    getCompletionFeatureValues(String targetType) =>
     _targetType_completion_featureValues[targetType];

  /// Method to update the model with a single feature vector
  addFeature(FeatureVector vector) {
    _completionsCount
      .putIfAbsent(vector.targetType, () => {})
      .putIfAbsent(vector.completion, () => 0);

    _completionsCount[vector.targetType][vector.completion]++;

    FeatureValueDistribution distribution =
    _targetType_completion_featureValues
      .putIfAbsent(vector.targetType, () => {})
      .putIfAbsent(vector.completion, () => new FeatureValueDistribution());

    for (var featureName in FeatureVector.allFeatureNames) {
      distribution.incrementFeatureValueCount(
        featureName, vector.getValue(featureName));
    }
  }

  /// Helper ctor to populate a feature model from a list of features
  /// this method is not performance sensitive
  FeatureServer.fromFeatures(Iterable<FeatureVector> features) {
    for (var vector in features) {
      addFeature(vector);
    }
  }

  FeatureServer.fromPaths(String completionCountPath, String featureValuesPath) {
    Stopwatch sw = new Stopwatch()..start();

    {
      var file = new io.File(completionCountPath);
      String completionCountStr = file.readAsStringSync();
      print ("${sw.elapsedMilliseconds}: CompletionCount read from file");

      _completionsCount = JSON.decode(completionCountStr);
      print ("${sw.elapsedMilliseconds}: CompletionCount decoded");
    }

    Map<String, Map<String, String>> codedFeatureValues;
    {
      var file = new io.File(featureValuesPath);
      String codedFeatureValuesStr = file.readAsStringSync();
      print ("${sw.elapsedMilliseconds}: Feature Values read from file");
      codedFeatureValues = JSON.decode(codedFeatureValuesStr);
    }
    print ("${sw.elapsedMilliseconds}: Feature Values decoded");

    for (var typeStr in codedFeatureValues.keys) {
      for (var completionStr in codedFeatureValues[typeStr].keys) {
        var codedValue = codedFeatureValues[typeStr][completionStr];

        var block = crypto.BASE64.decode(codedValue);

        _targetType_completion_featureValues
          .putIfAbsent(typeStr, () => {});

          _targetType_completion_featureValues[typeStr][completionStr] =
            new FeatureValueDistribution.fromStorageBlock(block);
      }
      // Allow incremental removal of the data structures to decrease peak memory usage
      codedFeatureValues[typeStr].clear();
    }
    print ("${sw.elapsedMilliseconds}: Feature Values unpacked");

  }

  toPath(String completionCountPath, String featureValuesPath) {

    var file = new io.File(completionCountPath);
    if (file.existsSync()) file.deleteSync();

    // Write the completions Count
    file.writeAsStringSync(JSON.encode(_completionsCount) + "\n");

    file = new io.File(featureValuesPath);
    if (file.existsSync()) file.deleteSync();

    // Encode the value distributions as UTF coded byte blocks
    Map<String, Map<String, String>> codedFeatureValues = {};

    for (var typeStr in _targetType_completion_featureValues.keys) {
      for (var completionStr in _targetType_completion_featureValues[typeStr].keys) {
        var codedValue =
          crypto.BASE64.encode(
             _targetType_completion_featureValues[typeStr][completionStr]
               .toStorageByteBlock());
        codedFeatureValues.putIfAbsent(typeStr, () => {});
        codedFeatureValues[typeStr][completionStr] = codedValue;
      }
    }

    file.writeAsStringSync(JSON.encode(codedFeatureValues) + "\n");
  }
}
