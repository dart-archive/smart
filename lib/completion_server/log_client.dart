// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library smart.completion_server.log_client;

import 'dart:io';
import 'dart:async';

enum LogTarget {
  LOG_SERVER,
  STDOUT
}

// Log test driver
main(List<String> args) async {
  print ("Log test driver, pushes data to the local log server");
  while (true) {
    await info("test", "=====================================");
    await new Future.delayed(new Duration(milliseconds: 5000));
  }
}

const LogTarget TARGET = LogTarget.LOG_SERVER;
const int LOG_SERVER_PORT = 9991;

Future info(String srcName, String logItem) async {
  String logLine = "${new DateTime.now().toIso8601String()}: $srcName: $logItem";
  switch (TARGET) {
    case LogTarget.STDOUT:
      print (logLine);
      break;
    case LogTarget.LOG_SERVER:
      return new HttpClient().post(
        InternetAddress.LOOPBACK_IP_V4.host, LOG_SERVER_PORT, '/').then((req) {
          req.write(logLine);
          return req.flush().then((_) {
            return req.close();
          });
        });
  }
}
