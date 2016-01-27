// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_model.model;

import '../completion_server/feature_server.dart';
import '../completion_server/log_client.dart' as log_client;

import 'dart:io' as io;
import 'package:logging/logging.dart' as log;
import 'ast_extractors.dart';


const ENABLE_DIAGNOSTICS = false;
const DISABLED_FEATURES = const [];

class Model {
  int modelSwitchThreshold;
  num smoothingFactor;
  FeatureServer server;
  log.Logger _logger;

  // Cache the model data
  //targetType -> feature -> completionResult -> featureValue__count
  // var dataModel;

  //targetType -> completionResult -> count
  // Map<String, Map<String, num>> targetTypeCompletionCount;

  Model(String featuresPath,
      [this.modelSwitchThreshold = 3, this.smoothingFactor = 0.0000001]) {
        _logger = new log.Logger("smart.completion_model.model");
        log_client.bindLogServer(_logger);

        _logger.info("About to start feature server: $featuresPath");
    server = FeatureServer.startFromPath(featuresPath);
  }

  Map<String, Map<String, num>> scoreCompletionOrder(var featureMap) {
    _logger.fine("scoreCompletionOrder: $featureMap");

    /* The probability of the completion 'toString' being accepted correlates to:
    P(completion == "toString" | context) ~=
      P(completion == "toString) *
      P(inClass == context[inClass] | completion == "toString") *
      P(... == context[...] | completion == "toString") *
      ...
     */

    Map<String, Map<String, num>> completionScores = {};

    // Get a list of completions that we've seen for this type
    var targetType = featureMap["TargetType"];
    var serverMap = server.getFeaturesFor(targetType);

    if (targetType == null ||
        serverMap == null ||
        serverMap.completionResult_count == null) {
      _logger.info("Type not seen before: $targetType, "
          "${serverMap == null} "
          "${serverMap.completionResult_count == null}");

      // We've never seen this type before, this simple model should just
      // return a uniform model
      return null;
    }

    var completionResultsMap = serverMap.completionResult_count;

    List<String> seenCompletions = completionResultsMap.keys.toList();
    num totalSeenCount = completionResultsMap.values.reduce(sum);

    for (String completion in seenCompletions) {
      completionScores.putIfAbsent(completion, () => {});

      // Compute P(c == completion)
      num pCompletion = completionResultsMap[completion] / totalSeenCount;
      completionScores[completion]["pCompletion"] = pCompletion;

      num pFeatures = 1;
      // Compute the other features
      for (String featureName in featureMap.keys) {
        if (featureName == "TargetType" ||
            featureName == COMPLETION_KEY_NAME) continue;

        // Skip any features that are disabled in the model
        if (DISABLED_FEATURES.contains(featureName)) continue;

        // Lookup the value for this feature for completion query
        var featureValue = "${featureMap[featureName]}";

        // targetType -> feature -> completionResult -> featureValue :: count
        // Lookup this value in the main model
        Map<dynamic, num> featureValue__count =
            serverMap.featureName_completionResult_featureValue_count[
                featureName][completion];

        // For the given [completion] the counts of the feature values are now
        // in featureValue__count

        // If this is null, it's because this part of the model has been pruned
        // We can simulate this by creating an empty map
        if (featureValue__count == null) featureValue__count = {};

        // Compute the total for this feature value
        num totalForThisValue = featureValue__count.values.reduce(sum);

        // P(this feature)
        num pFeature = 1;

        String featureLookup = "$featureName = $featureValue";

        if (featureValue__count.containsKey(featureValue)) {
          num smoothedValueCount =
              (featureValue__count[featureValue] + smoothingFactor);

          if (smoothedValueCount < modelSwitchThreshold) {
            // Use 'unseen estimator'
            pFeature = (smoothedValueCount / totalSeenCount);
            // Mark the features with an unseen case estimator
            featureLookup =
                featureLookup + " U_$smoothedValueCount/$totalSeenCount";
          } else {
            pFeature = (smoothedValueCount / totalForThisValue);
            featureLookup =
                featureLookup + " _$smoothedValueCount/$totalForThisValue";
          }
        } else {
          pFeature = (smoothingFactor / totalSeenCount); // Smoothing factor
          // Mark the features with an unseen case estimator
          featureLookup = featureLookup + " X_$smoothingFactor/$totalSeenCount";

          if (ENABLE_DIAGNOSTICS) {
            _logger.finest("");

            _logger.finest(" === Query === ");
            _logger.finest("featureName: $featureName featureValue: $featureValue");

            _logger.finest(" === Total Seen Count === ");
            _logger.finest("$totalSeenCount");
            _logger.finest(" === Map === ");
            _logger.finest("$featureValue__count");
            _logger.finest(" === containsKey === ");
            _logger.finest("${featureValue__count.containsKey(featureValue)}");
            _logger.finest(" === key type === ");
            _logger.finest("${featureValue.runtimeType}");
            _logger.finest(" === End ===");
            _logger.finest("");
          }
        }

        completionScores[completion][featureLookup] = pFeature;
        pFeatures *= pFeature;
      }
      completionScores[completion]["Overall_PValue"] = pCompletion * pFeatures;
    }
    return completionScores;
  }
}

sum(a, b) => a + b;

// Support methods
// TODO(lukechurch): Refactor these to a shared library
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

String _diagnosticsPrint(List<String> completionOrder,
    Map<String, Map<String, num>> completionFeatures) {
  StringBuffer sb = new StringBuffer();

  for (String completion in completionOrder) {
    sb.writeln("$completion: ${completionOrder.indexOf(completion)}");
    _prettyPrintRecursive(completionFeatures[completion], sb, 1);
  }

  return sb.toString();
}
