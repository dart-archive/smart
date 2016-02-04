// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:smart/completion_server/feature_server.dart' as server;
import 'dart:io';
import 'dart:async';

main(List<String> args) async {

  Stopwatch sw = new Stopwatch()..start();

  var featureServer = server.FeatureServer.startFromPath(args[0]);

  print ("Model loaded in: ${sw.elapsedMilliseconds}");

  featureServer.exportToPackedFormat(args[0]);

  print ("Model exported in: ${sw.elapsedMilliseconds}");

  //
  // print ("Starting");
  //
  // var featureServer = server.FeatureServer.startFromPackedPath(args[0]);
  //
  // print ("Model exported in: ${sw.elapsedMilliseconds}");


  // for (int i = 0; i < 1000; i++) {
  //   await new Future.delayed(new Duration(seconds: 10));
  // }
}
