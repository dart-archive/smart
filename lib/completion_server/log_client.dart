// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.log_client;

import 'dart:io' as io;
import 'dart:async';
import 'package:logging/logging.dart' as logging;

void bindLogServer(logging.Logger logger, {target : LogTarget.LOG_SERVER}) {
  logger.onRecord.listen((logItem) {
    _record("${logItem.level}", logItem.sequenceNumber, logItem.loggerName,
        logItem.message, target);
  });
}

enum LogTarget { LOG_SERVER, STDOUT }

// Log test driver
main(List<String> args) async {
  logging.Logger logger = new logging.Logger("Test");
  bindLogServer(logger);

  print("Log test driver, pushes data to the local log server");
  while (true) {
    logger.info("=====================================");
    await new Future.delayed(new Duration(milliseconds: 5000));
  }
}

const int LOG_SERVER_PORT = 9991;

Future _record(String level, int seqNumber, String srcName, String logItem,
    LogTarget _target) async {
  String logLine =
      "$seqNumber ${new DateTime.now().toIso8601String()}: $srcName: $logItem";
  switch (_target) {
    case LogTarget.STDOUT:
      print(logLine);
      break;
    case LogTarget.LOG_SERVER:
      return new io.HttpClient()
          .post(io.InternetAddress.LOOPBACK_IP_V4.host, LOG_SERVER_PORT, '/')
          .then((req) {
        req.write(logLine);
        return req.flush().then((_) {
          return req.close();
        });
      });
  }
}
