// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.feature_server;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class FeaturesForType {
  String targetType;

  // Note that the breaking of Dart standard variable naming is intentional

  //targetType -> featureName -> completionResult -> featureValue__count
  Map<String, Map<String, Map<dynamic, num>>>
    featureName_completionResult_featureValue_count = {};

  //targetType -> completionResult -> count
  Map<String, num> completionResult_count = {};

  FeaturesForType(
    this.featureName_completionResult_featureValue_count,
    this.completionResult_count
  );
}

class FeatureServer {
  Map<String, FeaturesForType> featureMap = {};

  /// [completionCountJSON] is exported by the feature indexer as
  ///  targetType_completionResult__count.json
  ///  [featureValuesJSON] is exported exported by the feature indexer as
  ///  targetType_feature_completionResult_featureValue__count
  FeatureServer(String completionCountJSON, String featureValuesJSON) {

    //Target Type -> Feature -> Completion result -> Feature Value : Count
    Map<String, Map<String, Map<String, Map<String, int>>>>
      targetType_feature_completionResult_featureValue__count =
      JSON.decode(featureValuesJSON);

    //Target Type -> Completion -> Count
    Map<String, Map<String, int>> targetType_completionResult__count =
      JSON.decode(completionCountJSON);

    for (String targetType in targetType_completionResult__count.keys) {
      FeaturesForType feature = new FeaturesForType(
        targetType_feature_completionResult_featureValue__count[targetType],
        targetType_completionResult__count[targetType]
      );
      featureMap[targetType] = feature;
    }
  }

  static FeatureServer startFromPath(String basePath) {
    String completionCountJSON =
      new File(path.join(basePath,"targetType_completionResult__count.json"))
      .readAsStringSync();

    String featureValuesJSON =
      new File(path.join(basePath,"targetType_feature_completionResult_featureValue__count.json"))
      .readAsStringSync();

    return new FeatureServer(completionCountJSON, featureValuesJSON);
  }
}
