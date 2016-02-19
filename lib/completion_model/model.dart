// // Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// // for details. All rights reserved. Use of this source code is governed by a
// // BSD-style license that can be found in the LICENSE file.
//
library smart.completion_model.model;

import 'package:smart/completion_server/feature_server.dart';
import 'package:smart/completion_server/log_client.dart' as log_client;

import 'package:logging/logging.dart' as log;
import 'feature_vector.dart';

const ENABLE_DIAGNOSTICS = false;

/// [Model] encapsulates the Bayesian model for using the features to
/// predict an ordering on completions
class Model {
  int modelSwitchThreshold;
  num smoothingFactor;
  FeatureServer server;
  log.Logger _logger;
  List<String> skippedFeatureNames = [];

  Model(this.server,
      [this.modelSwitchThreshold = 3, this.smoothingFactor = 0.0000001,
        this.skippedFeatureNames]) {
    _logger = new log.Logger("smart.completion_model.model");
    log_client.bindLogServer(_logger);
  }

  /// Returns a sorted list of completions in increasing order of probability.
  List<CompletionResult> scoreCompletionOrder(FeatureVector vector) {
    /*
    The probability distribution is separated for each type

    The probability of the completion 'toString' being accepted correlates to:
    P(completion == "toString" | context) ~=
      P(completion == "toString) *
      P(inClass == context[inClass] | completion == "toString") *
      P(... == context[...] | completion == "toString") *
      ...
    */

    if (vector.targetType == null) {
      _logger.info("Target type null, return uniform probability");
      return [];
    }

    // The global probability is estimated based purely on relative frequency
    // This map will serve as the data source
    Map<String, int> completionCount =
        server.getCompletionCount(vector.targetType);

    if (completionCount == null) {
      _logger.info("Target type null, return uniform probability");
      return [];
    }


    Map<String, FeatureValueDistribution> completionFeatureDistribution =
        server.getCompletionFeatureValues(vector.targetType);

    final int totalCompletionsSeenForThisTarget =
        completionCount.values.fold(0, (a, b) => a + b);

    List<CompletionResult> results = <CompletionResult>[];

    for (String completion in completionCount.keys) {
      CompletionResult result = new CompletionResult();

      result.completion = completion;

      // P(c == completion)
      num score =
          completionCount[completion] / totalCompletionsSeenForThisTarget;
      result.featureValues["_P(completion)"] = score;

      var featureDistribution = completionFeatureDistribution[completion];

      // Compute probabilities for each of the features
      // for (var featureName in vector.allFeatureNames) {
      for (int index = 0; index < FeatureVector.featureCount; index++) {
        String featureName = FeatureVector.getFeatureNameFromIndex(index);
        if (skippedFeatureNames.contains(featureName)) continue;

        // feature value from the completion request
        var featureValue = vector.getValueFromIndex(index);

        int totalCountForFeature =
            featureDistribution.getTotalCountForFeatureIndex(index);

        int countForFeatureValue =
            featureDistribution.getValueCountForFeatureIndex(index, featureValue);
        if (countForFeatureValue == null) countForFeatureValue = 0;

        num smoothedCount = countForFeatureValue + smoothingFactor;

        var pFeatureValue;

        // P(inClass == context[inClass] | completion == "toString") *
        // P(... == context[...] | completion == "toString") *

        if (totalCountForFeature < modelSwitchThreshold) {
          // We haven't seen enough information for any values for this
          // feature, revert to a uniform model
          pFeatureValue = smoothedCount / totalCompletionsSeenForThisTarget;
          result.featureValues["${featureName}__globalUnseen"] = pFeatureValue;
        } else if (smoothedCount < modelSwitchThreshold) {
          // For very small counts this will over-estimate
          pFeatureValue = smoothingFactor / totalCompletionsSeenForThisTarget;
          result.featureValues["${featureName}__localUnseen"] = pFeatureValue;
        } else {
          pFeatureValue = smoothedCount / totalCountForFeature;
          result.featureValues[featureName] = pFeatureValue;
        }
        score *= pFeatureValue;
      }
      result.score = score;
      results.add(result);
    }

    // Reverse sort the results
    results.sort((r1, r2) => -1 * r1.score.compareTo(r2.score));
    return results;
  }
}

class CompletionResult {
  /// The proposed result
  String completion;

  /// [score] correlates with estimated probability
  num score;

  // Optional aditional structure that is included in diagnostics mode
  Map<String, num> featureValues = {};

  String toString() => "$completion: $score";
}
