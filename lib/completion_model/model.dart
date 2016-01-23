// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_model.model;

import '../completion_server/feature_server.dart';
import 'ast_extractors.dart';
import 'package:sintr_common/logging_utils.dart' as log;

const ENABLE_DIAGNOSTICS = true;
const DISABLED_FEATURES = const [];

class Model {
  int modelSwitchThreshold;
  num smoothingFactor;
  FeatureServer server;

  // Cache the model data
  //targetType -> feature -> completionResult -> featureValue__count
  // var dataModel;

  //targetType -> completionResult -> count
  // Map<String, Map<String, num>> targetTypeCompletionCount;

  Model(String featuresPath,
      [this.modelSwitchThreshold = 3, this.smoothingFactor = 0.0000001]) {
    log.setupLogging("smart");
    log.trace("About to start feature server: $featuresPath");
    server = FeatureServer.startFromPath(featuresPath);
  }

  Map<String, Map<String, num>> scoreCompletionOrder(var featureMap) {
    log.trace("scoreCompletionOrder: $featureMap");

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

    if (targetType == null ||
        server.featureMap[targetType].completionResult_count == null) {
      // We've never seen this type before, this simple model should just
      // return a uniform model
      return null;
    }

    List<String> seenCompletions =
        server.featureMap[targetType].completionResult_count.keys.toList();

    num totalSeenCount =
        server.featureMap[targetType].completionResult_count.values.reduce(sum);

    for (String completion in seenCompletions) {
      completionScores.putIfAbsent(completion, () => {});

      // Compute P(c == completion)
      num pCompletion = server.featureMap[targetType].completionResult_count[
              completion] /
          totalSeenCount;

      completionScores[completion]["pCompletion"] = pCompletion;

      num pFeatures = 1;
      // Compute the other features
      for (String featureName in featureMap.keys) {
        if (featureName == "TargetType" ||
            featureName == COMPLETION_KEY_NAME) continue;

        // Skip any features that are disabled in the model
        if (DISABLED_FEATURES.contains(featureName)) continue;

        // Lookup the value for this feature for query
        var featureValue = "${featureMap[featureName]}";

        // targetType -> feature -> completionResult -> featureValue :: count
        // Lookup this value in the main model
        Map<dynamic, num> featureValue__count = server.featureMap[targetType]
                .featureName_completionResult_featureValue_count[featureName]
            [completion];
        assert(featureValue__count != null);

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
            featureLookup = featureLookup +
                " U_$smoothedValueCount/$totalSeenCount";
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
            log.debug("");

            log.debug(" === Query === ");
            log.debug("featureName: $featureName featureValue: $featureValue");

            log.debug(" === Total Seen Count === ");
            log.debug("$totalSeenCount");
            log.debug(" === Map === ");
            log.debug("$featureValue__count");
            log.debug(" === containsKey === ");
            log.debug("${featureValue__count.containsKey(featureValue)}");
            log.debug(" === key type === ");
            log.debug("${featureValue.runtimeType}");
            log.debug(" === End ===");
            log.debug("");
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
