// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:smart/completion_model/analyse_path.dart' as completion_model;
import 'dart:io' as io;
import 'package:sintr_common/logging_utils.dart' as log;


main(List<String> args) async {
  log.setupLogging();

  if (args.length != 1) {
    print ("Usage dart local_extractor_driver.dart path");
    print ("Diagnostics tool for debugging features from a given path");
    io.exit(1);
  }

  var result = await completion_model.analyseFolder(args[0]);
  print (result);

}
