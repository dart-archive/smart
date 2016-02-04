// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(Move this to the driver code)

/// Utility for extracting the features from a root folder
library smart.discovery_models.analysis_path;

import 'package:cli_util/cli_util.dart' as cli_util;

import 'dart:io' as io;
import 'dart:async';
import 'feature_extractor.dart' as extractor;
import 'package:sintr_common/logging_utils.dart' as log;

String pathToSdk;

Future<Map> analyseFolder(String path) async {
  log.trace("analyseFolder $path");

  pathToSdk = cli_util.getSdkDir().path;
  log.trace("analyseFolder SDK: $pathToSdk");

  extractor.Analysis analysis = new extractor.Analysis(pathToSdk);

  var fileMap = {};
  var inDir = new io.Directory.fromUri(new Uri.file(path));
  for (var f in inDir.listSync(recursive: true, followLinks: false)) {
    if (f is io.File) {
      try {
        if (f.path.endsWith(".dart")) {
          if (f.path.contains(".pub") || f.path.contains("packages")) {
            log.trace("Skipping: ${f.path} due to .pub | packages");
            continue;
          }

          log.trace("Analysing: ${f.path}");

          var features = analysis.analyzeSpecificFile(f.path);
          Map resultsMap = {"discovery_features": features};
          fileMap[f.path] = resultsMap;
        }
      } catch (e, st) {
        log.trace("ERR $e $st");
      }
    }
  }

  return fileMap;
}
