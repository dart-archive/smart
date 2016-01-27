// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.feature_server;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart' as log;

import 'log_client.dart' as log_client;

class FeaturesForType {
  String targetType;

  // Note that the breaking of Dart standard variable naming is intentional

  //targetType -> featureName -> completionResult -> featureValue__count
  Map<String, Map<String, Map<dynamic, num>>>
    featureName_completionResult_featureValue_count = {};

  //targetType -> completionResult -> count
  Map<String, num> completionResult_count = {};

  FeaturesForType(this.featureName_completionResult_featureValue_count,
      this.completionResult_count);

  toJSON() {
    return JSON.encode({
      "targetType": targetType,
      "featureName_completionResult_featureValue_count":
          featureName_completionResult_featureValue_count,
      "completionResult_count": completionResult_count
    });
  }
}

class FeatureServer {
  static log.Logger _logger;

  Map<String, FeaturesForType> _featureMap = {};
  FeaturesForType getFeaturesFor(String targetType) {
    _logger.fine("feature_server: getFeaturesFor", targetType);
    return _featureMap[targetType];
  }

  /// [completionCountJSON] is exported by the feature indexer as
  ///  targetType_completionResult__count.json
  ///  [featureValuesJSON] is exported exported by the feature indexer as
  ///  targetType_feature_completionResult_featureValue__count
  FeatureServer(String completionCountJSON, String featureValuesJSON) {
    Stopwatch sw = new Stopwatch()..start();
    //Target Type -> Feature -> Completion result -> Feature Value : Count
    Map<String,Map<String,Map<String,Map<String,int>>>>
      targetType_feature_completionResult_featureValue__count =
        JSON.decode(featureValuesJSON);

    //Target Type -> Completion -> Count
    Map<String, Map<String, int>> targetType_completionResult__count =
        JSON.decode(completionCountJSON);

    for (String targetType in targetType_completionResult__count.keys) {
      FeaturesForType feature = new FeaturesForType(
          targetType_feature_completionResult_featureValue__count[targetType],
          targetType_completionResult__count[targetType]);
      _featureMap[targetType] = feature;
    }

    _logger.fine(
        "feature_server: load from JSON:", "${sw.elapsedMilliseconds}");
  }

  static FeatureServer startFromPath(String basePath) {
    _logger = new log.Logger("feature_server");
    log_client.bindLogServer(_logger);

    _logger.fine("feature_server: startFromPath:", basePath);
    Stopwatch sw = new Stopwatch()..start();

    String completionCountJSON =
        new File(path.join(basePath, "targetType_completionResult__count.json"))
            .readAsStringSync();

    String featureValuesJSON = new File(path.join(basePath,
            "targetType_feature_completionResult_featureValue__count.json"))
        .readAsStringSync();

    _logger.info(
        "feature_server: load from disk:", "${sw.elapsedMilliseconds}");

    return new FeatureServer(completionCountJSON, featureValuesJSON);
  }
}
