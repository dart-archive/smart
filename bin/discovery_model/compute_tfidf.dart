// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert';
import 'dart:math' as math;

Map<String, Map<String, int>> typeIndex = {};
Map<String, Map<String, num>> typeTFIDF = {};

int numberOfDocuments = 0;
const DIAGNOSTICS = false;

/// Export the tfidf for the results of the typeusage_reducer
main(List<String> args) {
  if (args.length != 1) {
    print("Usage: compute_tfidf [path_to_features_file]");
    io.exit(1);
  }
  typeIndex = JSON.decode(new io.File(args[0]).readAsStringSync());

  // Compute the number of documents
  var corpusSet = new Set();
  for (var k in typeIndex.keys) {
    corpusSet.addAll(typeIndex[k].keys);
  }

  numberOfDocuments = corpusSet.length;

  // Computing TF-IDF table
  for (String k in typeIndex.keys) {
    typeTFIDF.putIfAbsent(k, () => {});
    var inverseFreq = math.log(numberOfDocuments / typeIndex[k].length);
    for (var kk in typeIndex[k].keys) {
      typeTFIDF[k][kk] = typeIndex[k][kk] * inverseFreq;
    }
  }

  typeIndex = null;

  if (DIAGNOSTICS) {
    for (var k in typeTFIDF.keys) {
      print(k);
      var tdfifKeys = typeTFIDF[k].keys.toList()
        ..sort((a, b) => typeTFIDF[k][a].compareTo(typeTFIDF[k][b]));
      for (var kk in tdfifKeys.reversed) {
        print(" $kk ${typeTFIDF[k][kk]}");
      }
    }
  }

  print(JSON.encode(typeTFIDF));
}
