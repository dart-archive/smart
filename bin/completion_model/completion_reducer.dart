// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert' as convert;

import 'package:smart/completion_model/feature_vector.dart';
import 'package:smart/completion_server/feature_server.dart';

import 'package:path/path.dart' as path;

main(List<String> args) {
  if (args.length != 2) {
    print('Usage: completion_reducer features_path out_path');
    print(
    """This tool processes the results of the completion extractors and
       emits the packed file formats for the feature_server to load""");
    io.exit(1);
  }

  Stopwatch sw = new Stopwatch()..start();

  String inPath = args[0];
  print('in path: $inPath');

  String outPath = args[1];
  print('out path: $outPath');

  io.Directory inDir = new io.Directory(inPath);

  num i = 0;
  List<io.FileSystemEntity> fses = inDir.listSync(recursive: true);
  num max = fses.length.toDouble();

  FeatureServer model = new FeatureServer();

  // targetType -> Completion -> Files
  // This map is exported to assist with debugging
  Map<String, Map<String, List<String>>> featureProvenence = {};

  for (io.FileSystemEntity f in fses) {
    i++;
    if (f is io.File) {
      if (f.path.endsWith(".gz") && !f.path.contains("gstmp")) {
        print("${sw.elapsedMilliseconds}: ${i/max}: ${f.path}");

        var data = convert.JSON.decode(f.readAsStringSync());
        data = data['result'];

        for (var path in data.keys) {
          var completionFeatures = data[path]['completion_features'];
          if (completionFeatures == null) continue;
          for (var completionFeatureString in completionFeatures) {
            // Load the Feature Vector from the string
            var vector =
                new FeatureVector().fromJsonString(completionFeatureString);
            model.addFeature(vector);

            featureProvenence
                .putIfAbsent(vector.targetType, () => {})
                .putIfAbsent(vector.completion, () => [])
                .add(f.path);
          }
        }
      }
    }
  }

  model.toPath(path.join(outPath, "completion_count.json"),
      path.join(outPath, "packed_model.smart_complete"));

  new io.File(path.join(outPath, "featureProvenence.json"))
      .writeAsStringSync(convert.JSON.encode(featureProvenence));
}
