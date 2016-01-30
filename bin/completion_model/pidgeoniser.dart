// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pigeon_map/pigeon.dart' as bird;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;

const VEBOSE_DIAGNOSTICS = false;

main(List<String> args) async {

  // bird.PigeonMap pm = new bird.PigeonMap(new bird.NameSet(["a", "b", "c"]));

  if (args.length != 1) {
    print ("Usage: export_const_model <model_base_path>");
    print ("This renders the json file as a const_model");
    exit(1);
  }

  String basePath = args[0];

  Stopwatch sw = new Stopwatch()..start();

  String completionCountPath = path.join(
    basePath, "targetType_completionResult__count.json");

  String featureValuePath = path.join(
    basePath, "targetType_feature_completionResult_featureValue__count.json"
  );

  var completionMap = _compactCompletionCount(completionCountPath);
  var featureValuesMap = _compactFeatureValues(featureValuePath);

  await new Future.delayed(new Duration(seconds: 120));

  for (var k in featureValuesMap.keys) {
    print (k);
  }

  print ("Compaction completed: ${sw.elapsedMilliseconds} ms");
  sw.reset();

}

_compactCompletionCount(String completionCountPath) {
  Stopwatch sw = new Stopwatch()..start();
  String completionCountJSON = new File(completionCountPath).readAsStringSync();
  var completionCountMap = JSON.decode(completionCountJSON);
  print ("CompletionCount: ${sw.elapsedMilliseconds}");
  return completionCountMap;
}

_compactFeatureValues(String featureValuePath) {
  Stopwatch sw = new Stopwatch()..start();
  String featureValuesJSON = new File(featureValuePath).readAsStringSync();
  //Target Type -> Feature -> Completion result -> Feature Value : Count

  Map<String,bird.PigeonMap> flappyMap = {};

  Map<String,Map<String,Map<String,Map<String,int>>>>
    featureValuesMap = JSON.decode(featureValuesJSON);

  bird.NameSet featureNames = new bird.NameSet(featureValuesMap.values.first.keys);
  bird.NameSet featureValues = new bird.NameSet(['true', 'false']);

  for (String targetType in featureValuesMap.keys) {
    for (String featureName in featureValuesMap[targetType].keys) {
      for (String completion in featureValuesMap[targetType][featureName].keys) {
        for (String featureValue in featureValuesMap[targetType][featureName][completion].keys) {
          Map specificValueMap = featureValuesMap[targetType][featureName][completion];

          int count = specificValueMap[featureValue];

          print("$targetType, $featureName, $completion, $featureValue, $count");

          flappyMap.putIfAbsent(targetType, () => new bird.PigeonMap(featureNames))
          .putIfAbsent(featureName, () => {})
          .putIfAbsent(completion, () {
            // Is this one of the features that only uses the constrained feature set
            if (specificValueMap.keys.any((k) => !featureValues.contains(k))) {
              return {};
            } else {
              return new bird.PigeonMap(featureValues);
            }
          })
          .putIfAbsent(featureValue, () => count);
        }
      }
    }
  }
  print ("Feature Values: ${sw.elapsedMilliseconds}");
  return flappyMap;
}
