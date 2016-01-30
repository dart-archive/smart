// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.feature_server;

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart' as log;

import 'log_client.dart' as log_client;

class CompletionResultMap {
  // Completion Result -> Feature Value -> Count
  Map<String, FeatureValueMap> _featureValueMap = {};

  List<String> getCompletions() => _featureValueMap.keys.toList();
  FeatureValueMap getFeatureValueforCompletion(String completion) {
    return _featureValueMap[completion];
  }

  CompletionResultMap(Map<String, Map<dynamic, int>> completion_featureValue__count) {
    for (String completionResult in completion_featureValue__count.keys) {
      _featureValueMap[completionResult] = new FeatureValueMap(
        completion_featureValue__count[completionResult]
      );
    }
  }
}



class FeatureValueMap {
  static List<List> _sharedIndecies = [];
  static List<int> _indeciesUsages = [];
  int MAX_UNSHARED_SIZE = 25;


  List _valuesIndex = null;
  List<int> _count = null;

  List values() => _valuesIndex;
  int countForValue(var value) {
    int index = _valuesIndex.indexOf(value);
    if (index == -1) return null;
    return _count[index];
  }

  FeatureValueMap(Map<dynamic, int> countMap) {
    var keysList = countMap.keys.toList(growable: false);
    for (int i = 0; i < _sharedIndecies.length; i++) {
      List existingIndex = _sharedIndecies[i];
      if (existingIndex.length == keysList.length &&
        keysList.every((e) => existingIndex.contains(e))) {
          _valuesIndex = existingIndex;
          _indeciesUsages[i]++;
          break;
      }
    }

    if (_valuesIndex == null) {
      _valuesIndex = keysList;
      _sharedIndecies.add(_valuesIndex);
      _indeciesUsages.add(1);

      if (_indeciesUsages.where((i) => i == 1).length > MAX_UNSHARED_SIZE) {
        int indexToRemove;
        for (int i = 0; i < _indeciesUsages.length; i++) {
          if (_indeciesUsages[i] == 1) {
            indexToRemove = i;
            break;
          }
        }

        if (indexToRemove != null) {
          assert (_indeciesUsages[indexToRemove] == 1);
          _sharedIndecies.removeAt(indexToRemove);
          _indeciesUsages.removeAt(indexToRemove);
        }
      }

      print (_indeciesUsages);
    }

    _count = new List<int>(keysList.length);

    for (var k in keysList) {
      _count[_valuesIndex.indexOf(k)] = countMap[k];
      }
  }
}

class FeatureNamesMap {
  List<String> _featureNames = [];
  List<CompletionResultMap> _resultMap = [];

  CompletionResultMap getCompletionMapForFeature(String featureName) {
    int index = _featureNames.indexOf(featureName);
    if (index == -1) return null;
    return _resultMap[index];
  }
  List<String> getFeatureNames() => _featureNames.toList();

  FeatureNamesMap(Map<String, Map<String, Map<dynamic, int>>>
    featureName_completionResult_featureValue_count) {
    for (String featureName in featureName_completionResult_featureValue_count.keys) {
      _featureNames.add(featureName);
      _resultMap.add(new CompletionResultMap(
        featureName_completionResult_featureValue_count[featureName]));
    }
  }
}


class FeaturesForType {
  String targetType;
  FeatureNamesMap featureNamesMap;


  // Note that the breaking of Dart standard variable naming is intentional

  //featureName -> completionResult -> featureValue__count
  // Map<String, Map<String, Map<dynamic, num>>>
  //   featureName_completionResult_featureValue_count = {};

  //completionResult -> count
  Map<String, num> completionResult_count = {};

  FeaturesForType(featureName_completionResult_featureValue_count,
      completionResult_count) {
        this.completionResult_count = completionResult_count;

        featureNamesMap =
          new FeatureNamesMap(featureName_completionResult_featureValue_count);
      }

  // toJSON() {
  //   return JSON.encode({
  //     "targetType": targetType,
  //     "featureName_completionResult_featureValue_count":
  //         featureName_completionResult_featureValue_count,
  //     "completionResult_count": completionResult_count
  //   });
  // }
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
    log_client.bindLogServer(_logger, target: log_client.LogTarget.STDOUT);

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
