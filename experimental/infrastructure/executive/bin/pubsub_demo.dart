// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/logging_utils.dart' as log_utils;
import "package:sintr_common/configuration.dart" as config;

import 'package:executive/pubsub_utils.dart' as pubsub;
import 'package:gcloud/pubsub.dart' as ps_lib;
import 'package:gcloud/service_scope.dart' as ss;

main() async {
  final projectName = "liftoff-dev";
  final subscriptionName = "test_subscription";
  final topicName = "test_work";


  log_utils.setupLogging();
  config.configuration = new config.Configuration(projectName,
      cryptoTokensLocation:
          "${config.userHomePath}/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
    var ps = new ps_lib.PubSub(client, projectName);
    ss.fork(() async {
      var topic = await pubsub.getTopic(topicName, ps);
      var subscription = await pubsub.getSubscription(subscriptionName, topicName, ps);

      await publishTest(topic);
      log_utils.info("Test messages published");

      await readTest(subscription);
      log_utils.info("Subscription read complete");

    });
}

publishTest(ps_lib.Topic t) async {
  for (int i = 0; i < 100; i++) {
    await t.publishString("test-$i");
  }
}

readTest(ps_lib.Subscription s) async {
  while (true)
  {
    var pullEvent = await s.pull(wait: false);
    if (pullEvent == null) break; // If there weren't any messages

    print (pullEvent.message.asString);
    await pullEvent.acknowledge();
  }
}
