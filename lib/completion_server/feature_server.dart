// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.feature_server;

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart' as log;

import 'log_client.dart' as log_client;

class IndexedMap<K, V> {
  List<K> _index;
  List<V> _values;

  IndexedMap(Map<K,V> data, [List<List<K>> sharedIndecies]) {
    if (sharedIndecies == null) sharedIndecies = [];

    // See if we can reuse any of the existing indecies
    for (List existingIndex in sharedIndecies) {
      if (existingIndex.length == data.length
        && data.keys.every(existingIndex.contains)) {
          _index = existingIndex;
          break;
        }
    }
    if (_index == null) {
      _index = data.keys.toList(growable: false)..sort();
      sharedIndecies.add(_index);
    }
    _values = new List(data.length);
    for (int i = 0; i < data.length; i++) {
      _values[i] = data[_index[i]];
    }
  }

  get(K key) {
    // TODO: Replace this linear search with binary search where we have
    // a reliable comparator.
    int i = _index.indexOf(key);
    if (i == -1) {
      return null;
    } else {
      return _values[i];
    }
  }
  get keys => _index.toList();
  get values => _values.toList();
}

class FeatureNamesMap {
  // static List<List<String>> _sharedFeatureIndecies = [];
  IndexedMap<String, CompletionResultMap> _featureNamesMap;

  CompletionResultMap getCompletionMapForFeature(String featureName)
    => _featureNamesMap.get(featureName);

  List<String> getFeatureNames() => _featureNamesMap.keys;
  FeatureNamesMap(Map<String, Map<String, Map<dynamic, int>>>
    featureName_completionResult_featureValue_count, FeatureServer server) {

    Map scratch = {};
    for (String featureName in featureName_completionResult_featureValue_count.keys) {
      var completionResultMap = new CompletionResultMap(
        featureName_completionResult_featureValue_count[featureName], server);
      scratch[featureName] = completionResultMap;
    }

    _featureNamesMap = new IndexedMap(scratch, server._sharedFeatureNameIndecies);
  }
}

class CompletionResultMap {
  // Completion Result -> Feature Value -> Count
  Map<String, FeatureValueMap> _featureValueMap = {};

  List<String> getCompletions() => _featureValueMap.keys.toList();
  FeatureValueMap getFeatureValueforCompletion(String completion) {
    return _featureValueMap[completion];
  }

  CompletionResultMap(Map<String, Map<String, int>> completion_featureValue__count, FeatureServer server) {
    for (String completionResult in completion_featureValue__count.keys) {
      _featureValueMap[completionResult] = new FeatureValueMap(
        completion_featureValue__count[completionResult], server
      );
    }
  }
}

class FeatureValueMap {
  FeatureServer owningServer;
  // static List<List<String>> _sharedFeatureValueIndecies = [];
  IndexedMap<String, int> _featureNamesMap;

  List featureValues() => _featureNamesMap.keys;

  int countForValue(var value) {
    return _featureNamesMap.get(value);
  }

  FeatureValueMap(Map<dynamic, int> countMap, this.owningServer) {
    _featureNamesMap = new IndexedMap(countMap, owningServer._sharedFeatureValueIndecies);
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
      completionResult_count, FeatureServer server) {
        this.completionResult_count = completionResult_count;

        featureNamesMap =
          new FeatureNamesMap(featureName_completionResult_featureValue_count, server);
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

  List<List<String>> _sharedFeatureNameIndecies = [];
  List<List<String>> _sharedFeatureValueIndecies = [];


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

        int i = 0;

    for (String targetType in targetType_completionResult__count.keys) {
      print ("Type progress: ${i++ / (targetType_completionResult__count.keys.length)}");

      FeaturesForType feature = new FeaturesForType(
          targetType_feature_completionResult_featureValue__count[targetType],
          targetType_completionResult__count[targetType], this);
      _featureMap[targetType] = feature;
    }

    _logger.fine(
        "feature_server: load from JSON:", "${sw.elapsedMilliseconds}");
  }

  exportToPackedFormat(String basePath) {

    var outFile = new File(path.join(basePath, "featureVector.packed"));
    if (outFile.existsSync()) outFile.deleteSync();


    // Export the shared indecies
    String featureNamesMaps_sharedFeatureIndecies = JSON.encode(
      _sharedFeatureNameIndecies);

    outFile.writeAsStringSync(
      "featureNamesMaps_sharedFeatureIndecies: $featureNamesMaps_sharedFeatureIndecies\n"
    , mode: FileMode.APPEND);

    var featureValueMap_sharedFeatureValueIndecies = JSON.encode(
      _sharedFeatureValueIndecies);

    outFile.writeAsStringSync(
      "featureValueMap_sharedFeatureValueIndecies: $featureValueMap_sharedFeatureValueIndecies\n"
    , mode: FileMode.APPEND);

    for (String targetType in _featureMap.keys) {
      FeatureNamesMap featureNamesMap = _featureMap[targetType].featureNamesMap;

      int locationOfFeatureNamesMapIndex =
        _sharedFeatureNameIndecies.indexOf(
          featureNamesMap._featureNamesMap._index
      );

      outFile.writeAsStringSync(
        "targetType: $targetType\n"
      , mode: FileMode.APPEND);

      outFile.writeAsStringSync(
        "locationOfFeatureNamesMapIndex: $locationOfFeatureNamesMapIndex\n"
      , mode: FileMode.APPEND);

      List<CompletionResultMap> featureNameValues =
        featureNamesMap._featureNamesMap._values;

      for (CompletionResultMap completionResultMap in featureNameValues) {
        List completionResults = completionResultMap.getCompletions();

        outFile.writeAsStringSync(
          "completionResult: ${JSON.encode(completionResults)}\n"
        , mode: FileMode.APPEND);

        // print ("completionResult: ${JSON.encode(completionResults)}");

        for (String completion in completionResults) {

          FeatureValueMap featureValueMap =
            completionResultMap.getFeatureValueforCompletion(completion);

            // Location of feature value map
            int locationOfFeatureValueMapIndex =
              _sharedFeatureValueIndecies.indexOf(
                featureValueMap._featureNamesMap._index
              );

              outFile.writeAsStringSync(
                "locationOfFeatureNamesValueIndex: $locationOfFeatureValueMapIndex~"
              , mode: FileMode.APPEND);

              // print("locationOfFeatureNamesMapIndex: $locationOfFeatureValueMapIndex");
            // Feature values result
            var featureNamesValues =
              featureValueMap._featureNamesMap._values;

              outFile.writeAsStringSync(
                "${JSON.encode(featureNamesValues)}\n"
              , mode: FileMode.APPEND);

              // print("featureNamesValues: ${JSON.encode(featureNamesValues)}");

        }
      }
    }
  }

  static Future<FeatureServer> startFromPackedPath(String basePath) async {
    const HEADER_MARKER = true;

    // _logger = new log.Logger("feature_server");
    // log_client.bindLogServer(_logger, target: log_client.LogTarget.STDOUT);
    // log.Logger.root.level = log.Level.ALL;
    print("feature_server: startFromPacked: $basePath");
    print("${new DateTime.now()}");//" ${ln.length}");


    var inFile = new File(path.join(basePath, "featureVector.packed"));

    int lnCounter = 0;

    //featureNamesMaps_sharedFeatureIndecies:
    //featureValueMap_sharedFeatureValueIndecies:

    String expectStart = "targetType: ";

    var featureNamesMaps_sharedFeatureIndecies;
    var featureValueMap_sharedFeatureValueIndecies;

    // State machine working variables
    String targetType;
    int locationOfFeatureNamesMapIndex;
    List<String> completionResults;
    List<int> locationOfFeatureValueMapIndex;
    List<List<int>> featureNamesValues;

    int featureCounter = 0;
    int expectedFeatureCount;

    await for (String ln in inFile.openRead().transform(UTF8.decoder).transform(new LineSplitter())) {

      try {



      if (lnCounter == 0) {
        if (!ln.startsWith("featureNamesMaps_sharedFeatureIndecies: ")) throw "Structure match failure";

        // Strip header marker
        if (HEADER_MARKER) ln = ln.substring("featureNamesMaps_sharedFeatureIndecies:".length);
        featureNamesMaps_sharedFeatureIndecies = JSON.decode(ln);
        // print (featureNamesMaps_sharedFeatureIndecies);
        // exit(0);
      }

      if (lnCounter == 1) {
        if (!ln.startsWith("featureValueMap_sharedFeatureValueIndecies: ")) throw "Structure match failure";

        // Strip header marker
        if (HEADER_MARKER) ln = ln.substring("featureValueMap_sharedFeatureValueIndecies:".length);
        featureValueMap_sharedFeatureValueIndecies = JSON.decode(ln);

        print ("Shared indecies are loaded ok");
        // print (featureNamesMaps_sharedFeatureIndecies);
        // exit(0);
      }

      if (lnCounter > 1) {
        print (_short(ln));

        if (HEADER_MARKER && !ln.startsWith(expectStart))
          throw "Expectation not met, expected $expectStart got ${
            ln.substring(0, 25 > ln.length ? ln.length : 25)
          }";

        switch (expectStart) {
          case "targetType: ":
            targetType = ln.substring("targetType: ".length).trim();
            expectStart = "locationOfFeatureNamesMapIndex: ";
            break;

          case "locationOfFeatureNamesMapIndex: ":
            locationOfFeatureNamesMapIndex =
              int.parse(ln.substring("locationOfFeatureNamesMapIndex: ".length).trim());

            expectedFeatureCount = featureNamesMaps_sharedFeatureIndecies[locationOfFeatureNamesMapIndex].length;

            expectStart = "completionResult: ";
            break;

          case "completionResult: ":
            completionResults = JSON.decode(
              ln.substring("completionResult: ".length));


              locationOfFeatureValueMapIndex = [];
              featureNamesValues = [];

            expectStart = "locationOfFeatureNamesValueIndex: ";
            featureCounter++;
            break;

          case "locationOfFeatureNamesValueIndex: ":
            String text = ln.substring("locationOfFeatureNamesValueIndex: ".length);
            locationOfFeatureValueMapIndex.add(int.parse(text.split("~")[0]));
            featureNamesValues.add(JSON.decode(text.split("~")[1]));

            print ("locationOfFeatureValueMapIndex.length: ${locationOfFeatureValueMapIndex.length}");
            print ("featureNamesValues.length: ${featureNamesValues.length}");
            print ("completionResults.length: ${completionResults.length}");


            if (locationOfFeatureValueMapIndex.length ==
              featureNamesValues.length &&
              featureNamesValues.length == completionResults.length) {

                if (featureCounter < expectedFeatureCount) {
                  expectStart = "completionResult: ";
                } else {
                  featureCounter = 0;
                  expectStart = "targetType: ";
                }



                // Done with this list
                break;
              }

            break;
        }

        // exit(0);
      }



      lnCounter++;

} catch (e, st) {
  print (ln);
  print (e);
  print (st);
  exit(1);
}
      // List<String> lines = inFile.readAsLinesSync();
    }

    print("${new DateTime.now()}");//" ${ln.length}");

    return new Future.value(null);
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

_short(String ln) {
  return ln.substring(0, 25 > ln.length ? ln.length : 25);
}
