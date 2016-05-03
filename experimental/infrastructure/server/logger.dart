// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library logger;

trace(String message) => _log("TRACE", message);
debug(String message) => _log("DEBUG", message);
info(String message) => _log("INFO", message);

_log(String level, String message) {
  print("${new DateTime.now().toIso8601String()}: $level $message");
}
