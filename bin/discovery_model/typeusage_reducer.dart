// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert';

Map<String, Map<String, int>> typeIndex = {};

/// Export the type usage distribution from the results of the map
main(List<String> args) {
  if (args.length != 1) {
    print ("Usage: typeusage_reducer [path_to_features]");
    io.exit(1);
  }

  List<io.FileSystemEntity> fses =
    new io.Directory(args[0]).listSync(recursive: true);

  for (var fse in fses) {
    if (!fse.path.endsWith(".gz")) continue;

    var f = fse as io.File;
    var data = JSON.decode(f.readAsStringSync());
    for (var dataPath in data['result'].keys) {

      var fileName =
        f.path.split("2016-01").last + dataPath.split("data_working").last;
      var discoveryFeatures = data['result'][dataPath]['discovery_features'];
      for (var typeUsageKV in discoveryFeatures) {
        var type = typeUsageKV['TypeUsage'];
        typeIndex.putIfAbsent(type, () => {}).putIfAbsent(fileName, () => 0);
        typeIndex[type][fileName]++;
      }
    }
  }
  print (JSON.encode(typeIndex));
}
