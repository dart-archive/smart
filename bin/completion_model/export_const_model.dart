// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

const VEBOSE_DIAGNOSTICS = false;

main(List<String> args) {

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

  _compact(completionCountPath, featureValuePath);

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

_compact(String completionCountPath, String featureValuePath) {
  Stopwatch sw = new Stopwatch()..start();

  String completionCountJSON = new File(completionCountPath).readAsStringSync();
  String completionCountDART = "const completionCount = " + exportConst(completionCountJSON);
  new File(completionCountPath+".dart").writeAsStringSync(completionCountDART);
  print ("completionCountJSON: ${sw.elapsedMilliseconds} ms");
  sw.reset();

  String featureValuesJSON = new File(featureValuePath).readAsStringSync();
  String featureValuesDART = "const featureValues = " + exportConst(featureValuesJSON);
  new File(featureValuePath+".dart").writeAsStringSync(featureValuesDART);
  print ("featureValuesJSON: ${sw.elapsedMilliseconds} ms");
}


String exportConst(String jsonString) {
  var a = JSON.decode(jsonString);
  var sb = new StringBuffer();

  exportItem(a, sb);
  sb.write(';');

  return sb.toString();
}

exportMap(Map mp, StringBuffer sb, [int spaces = 0]) {
  sb.write("const {");
  for (var k in mp.keys) {
    sb.write('"""${clean(k.toString())}""" :');
    exportItem(mp[k], sb, spaces+2);
    sb.write(",\n");
  }
  sb.write("}\n");
}

exportList(List ls, StringBuffer sb, [int spaces = 0]) {
  sb.write("const [");
  for (var item in ls) {
    exportItem(item, sb, spaces +2);
    sb.write(",\n");
  }
  sb.write("]\n");
}

exportItem(dynamic d, StringBuffer sb, [int spaces = 0]) {
  if (d is Map) exportMap(d, sb, spaces + 2);
  if (d is List) exportList(d, sb, spaces + 2);
  if (d is String) sb.write('"""${clean(d)}"""');
  if (d is num) sb.write('$d'.padLeft(spaces));
}

String clean(String s) =>
  s.replaceAll("\$", "").replaceAll("\"", "").replaceAll("\\", "").replaceAll("'", "").replaceAll("\n", "");
