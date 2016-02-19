// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert' as convert;
import 'package:path/path.dart' as path;
import 'package:smart/completion_server/feature_server.dart';
import 'package:smart/completion_model/feature_vector.dart';
import 'package:smart/completion_model/model.dart';
import 'package:trotter/trotter.dart';

var perfScores = <int, int>{};

main(List<String> args) {
  if (args.length != 2) {
    print("Usage: optimiser model_path test_path");
    io.exit(1);
  }

  Stopwatch sw = new Stopwatch()..start();

  FeatureServer server = new FeatureServer.fromPaths(
      path.join(args[0], "completion_count.json"),
      path.join(args[0], "packed_model.smart_complete"));
  print("${sw.elapsedMilliseconds}: Model loaded");

  for (int i = 0; i < FeatureVector.featureCount; i++) {
    var combinations = new Combinations(i, FeatureVector.allFeatureNames);

    for (var c in combinations) {
      sw.reset();

      var model = new Model(server, 0, 0, c);
      evaluateModel(model, args[1]);
    }
  }
}

evaluateModel(Model model, String testPath) {
  List<io.FileSystemEntity> fses =
      new io.Directory(testPath).listSync(recursive: true);
  for (io.FileSystemEntity f in fses) {
    if (f is io.File) {
      if (f.path.endsWith(".gz") && !f.path.contains("gstmp")) {

        var data = convert.JSON.decode(f.readAsStringSync());
        data = data['result'];

        for (var path in data.keys) {
          var completionFeatures = data[path]['completion_features'];
          if (completionFeatures == null) continue;
          for (var completionFeatureString in completionFeatures) {
            // Load the Feature Vector from the string
            var vector =
                new FeatureVector().fromJsonString(completionFeatureString);

            if (vector.targetType == "dynamic") continue;

            // Stopwatch sw2 = new Stopwatch()..start();

            var results = model.scoreCompletionOrder(vector);
            int index = -1;

            for (int i = 0; i < results.length; i++) {
              if (results[i].completion == vector.completion) {
                index = i;
                break;
              }
            }

            if (results.length == 0) continue;
            perfScores.putIfAbsent(index, () => 0);
            perfScores[index]++;
          }
        }
      }
    }
  }
  num total = perfScores.values.fold(0, (a, b) => a + b);

  int top = 0;
  int top3 = 0;
  int top10 = 0;
  int acc = 0;

  for (var k in perfScores.keys.toList()..sort()) {
    int count = perfScores[k];
    acc += count;

    if (k == 0) top = count;
    if (k < 3) top3 = acc;
    if (k < 9) top10 = acc;

  }
  print(
      "Model Switch: ${model.modelSwitchThreshold} Smoothing: ${model.smoothingFactor} Skip: ${model.skippedFeatureNames} %Top: ${(top/total).toStringAsFixed(4)} %Top3: ${(top3/total).toStringAsFixed(4)} %Top10: ${(top10/total).toStringAsFixed(4)}");
}
