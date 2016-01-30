// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

const VEBOSE_DIAGNOSTICS = false;

main(List<String> args) {

  if (args.length != 2) {
    print ("Usage: model_compacter <model_base_path> <minimum_observed_count>");
    print ("This tool eliminates aspects of the model where insufficent is present");
    exit(1);
  }

  String basePath = args[0];
  int minCount = int.parse(args[1]);

  Stopwatch sw = new Stopwatch()..start();

  String completionCountPath = path.join(
    basePath, "targetType_completionResult__count.json");

  String featureValuePath = path.join(
    basePath, "targetType_feature_completionResult_featureValue__count.json"
  );

  _compact(completionCountPath, featureValuePath, minCount);

  print ("Compaction completed: ${sw.elapsedMilliseconds} ms");
  sw.reset();


  // List<int> serverStartPerfList = [];
  //
  // for (int i = 0; i < 10; i++) {
  //   server.FeatureServer.startFromPath(args[0]);
  //   serverStartPerfList.add(sw.elapsedMilliseconds);
  //   print ("Feature load completed: ${sw.elapsedMilliseconds}");
  //   sw.reset();
  //
  // }
  // print(serverStartPerfList);
}

_compact(String completionCountPath, String featureValuePath, int minCount) {
  String completionCountJSON = new File(completionCountPath).readAsStringSync();
  String featureValuesJSON = new File(featureValuePath).readAsStringSync();


  //Target Type -> Completion -> Count
  Map<String, Map<String, int>> targetType_completionResult__count =
    JSON.decode(completionCountJSON);

  //Target Type -> Feature -> Completion result -> Feature Value : Count
  Map<String, Map<String, Map<String, Map<String, int>>>>
    targetType_feature_completionResult_featureValue__count =
    JSON.decode(featureValuesJSON);

  List<String> targetTypes = targetType_completionResult__count.keys.toList();

  int removalCount = 0;
  for (String targetType in targetTypes) {
    int observedCount = targetType_completionResult__count[targetType].values.fold(0, (a, b) => a+b);
    if (observedCount < minCount) {
      if (VEBOSE_DIAGNOSTICS) print ("Removing: $targetType: $observedCount");

      removalCount++;
      targetType_completionResult__count.remove(targetType);
      targetType_feature_completionResult_featureValue__count.remove(targetType);
    }
  }
  print ("Compaction removed $removalCount of ${targetTypes.length}");

  print ("Compaction phase 1 complete: Type stripped");

  removalCount = 0;

  for (String targetType in targetType_feature_completionResult_featureValue__count.keys) {
    for (String featureName in targetType_feature_completionResult_featureValue__count[targetType].keys) {
      for (String completionResult in targetType_feature_completionResult_featureValue__count[targetType][featureName].keys) {
        var featureValue__count = targetType_feature_completionResult_featureValue__count[targetType][featureName][completionResult];

        num totalForThisValue = featureValue__count.values.reduce(sum);

        if (totalForThisValue < minCount) {
          removalCount++;
          targetType_feature_completionResult_featureValue__count[targetType][featureName][completionResult] = null;
        }
      }
    }
  }

  print ("Compaction removed $removalCount subtrees");

  new File(completionCountPath.split(".json")[0]+".compacted.json")
    .writeAsStringSync(JSON.encode(targetType_completionResult__count));

  new File(featureValuePath.split(".json")[0]+".compacted.json")
    .writeAsStringSync(
      JSON.encode(targetType_feature_completionResult_featureValue__count));

}
sum(a, b) => a + b;
