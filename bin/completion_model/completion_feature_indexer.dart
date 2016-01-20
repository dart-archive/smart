// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;
import 'dart:convert' as convert;

//Target Type -> Feature -> Completion result -> Feature Value : Count
Map<String, Map<String, Map<String, Map<String, int>>>> targetType_feature_completionResult_featureValue__count = {};

//Target Type -> Feature -> Feature Value -> Completion result : Count
Map<String, Map<String, Map<String, Map<String, int>>>> targetType_feature_featureValue_completionResult__count = {};

//Target Type -> Completion -> Count
Map<String, Map<String, int>> targetType_completionResult__count = {};

main(List<String> args) {
  print(args);
  print('working dir: ${new io.File('.').resolveSymbolicLinksSync()}');

  if (args.length != 2) {
    print('Usage: completion_feature_indexer features_path out_path');

    io.exit(1);
  }

  String path = args[0];
  print('in path: $path');

  String outPath = args[1];
  print('out path: $outPath');


  io.Directory inDir = new io.Directory(path);

  num i = 0;
  List<io.FileSystemEntity> fses = inDir.listSync(recursive: true);
  num max = fses.length.toDouble();

  for (io.FileSystemEntity f in fses) {
    i++;
    if (f is io.File) {
      if (f.path.endsWith(".json") && !f.path.contains("gstmp")) {
        print ( "${i/max}: ${f.path}");
        _processJSONString(f.readAsStringSync());
      }
    }
  }

  // Export the summaries

  new io.File("$outPath/targetType_feature_completionResult_featureValue__count.json").writeAsStringSync(convert.JSON.encode(targetType_feature_completionResult_featureValue__count));
  new io.File("$outPath/targetType_feature_completionResult_featureValue__count.pretty").writeAsStringSync(_prettyPrint(targetType_feature_completionResult_featureValue__count));

  new io.File("$outPath/targetType_feature_featureValue_completionResult__count.json").writeAsStringSync(convert.JSON.encode(targetType_feature_featureValue_completionResult__count));
  new io.File("$outPath/targetType_feature_featureValue_completionResult__count.pretty").writeAsStringSync(_prettyPrint(targetType_feature_featureValue_completionResult__count));

  new io.File("$outPath/targetType_completionResult__count.json").writeAsStringSync(convert.JSON.encode(targetType_completionResult__count));
  new io.File("$outPath/targetType_completionResult__count.pretty").writeAsStringSync(_prettyPrint(targetType_completionResult__count));


  new io.Directory("$outPath/targetTypeFeatures").createSync();
  new io.Directory("$outPath/targetTypeCompletion").createSync();

  for (var k in targetType_feature_completionResult_featureValue__count.keys) {
    new io.File("$outPath/targetTypeFeatures/$k.json").writeAsStringSync(
      convert.JSON.encode(targetType_feature_completionResult_featureValue__count[k])
    );
  }

  for (var k in targetType_completionResult__count.keys) {
    new io.File("$outPath/targetTypeCompletion/$k.json").writeAsStringSync(
      convert.JSON.encode(targetType_completionResult__count[k])
    );
  }

}



_processJSONString(String jsonStr) {

  const COMPLETION_KEY_NAME = "**Completion";


  var json = convert.JSON.decode(jsonStr);

  // The JSON structure looks like:

  /*
  {"result":
	 {"/home/lukechurch/data_working/zpaq_zpaq-tools/zpaq-tools/convert_zpaq.dart":{
		"features":
			[null,
				{"InClass":false,"InMethod":false, ...
  */

  Map resultsByPath = json["result"];

  if (resultsByPath == null) return;

  for (String path in resultsByPath.keys) {
    List allFeatureList = resultsByPath[path]["features"];
    for (Map featureMap in allFeatureList) {

      if (featureMap == null) continue;

      String completion = featureMap[COMPLETION_KEY_NAME];
      String targetType = featureMap["TargetType"];

      targetType_completionResult__count
        .putIfAbsent(targetType, () => {})
        .putIfAbsent(completion, () => 0);
      targetType_completionResult__count[targetType][completion]++;

      for (var k in featureMap.keys) {
        if (k == COMPLETION_KEY_NAME) continue;
        String v = featureMap[k].toString();

        // Ensure the structure is established
        targetType_feature_completionResult_featureValue__count
          .putIfAbsent(targetType, () => {})
          .putIfAbsent(k, () => {})
          .putIfAbsent(completion, () => {})
          .putIfAbsent(v, () => 0);

        targetType_feature_completionResult_featureValue__count[targetType][k][completion][v]++;

        targetType_feature_featureValue_completionResult__count
          .putIfAbsent(targetType, () => {})
          .putIfAbsent(k, () => {})
          .putIfAbsent(v, () => {})
          .putIfAbsent(completion, () => 0);
        targetType_feature_featureValue_completionResult__count[targetType][k][v][completion]++;
      }
    }
  }
}



// Methods for printing the maps in a form suitable for debugging

String _prettyPrint(Map results) {
  StringBuffer sb = new StringBuffer();
  _prettyPrintRecursive(results, sb, 0);
  return sb.toString();
}

_prettyPrintRecursive(Map results, StringBuffer sb, int tabs) {

  bool lastLevel = results.values.first is! Map;

  for (String k in results.keys) {
    for (int i = 0; i < tabs; i++) sb.write("\t");

    if (lastLevel) {
      sb.writeln("$k : ${results[k]}");
    } else {
      sb.writeln("$k");
      _prettyPrintRecursive(results[k], sb, tabs + 1);
    }
  }
}
