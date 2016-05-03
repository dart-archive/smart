// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library ingress;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'logger.dart' as log;
import 'components.dart';
import 'auditor.dart';

const PORT = 9999;
const DEBUG = true; // Insecure but with easier debugging

const routes = const {
  "statusz" : status,
  "update" : update,
  "notifywait" : notifyWait
};

Stopwatch uptime;

main() async {
  uptime = new Stopwatch()..start();
  var server = await HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, PORT);
  log.info("Server listening to $PORT");

  await for (HttpRequest req in server) {
    log.trace("Server recieved: ${req.method} ${req.uri}");
    var pathSegments = req.uri.pathSegments;

    try {
      if (pathSegments.length == 0 || !routes.keys.contains(pathSegments.first)) {
        req.response.statusCode = 404;
        if (DEBUG) req.response.writeln("Not found: ${req.uri}");
      } else {
        await routes[pathSegments.first](req);
        req.response.statusCode = 200;
      }
    } catch (e, st) {
      log.debug("$e \n $st");
      req.response.statusCode = 500;
      if (DEBUG) req.response.writeln("$e \n $st");
    } finally {
      req.response.close();
    }
  }
}

status(HttpRequest req) {
  req.response..writeln("Uptime: ${uptime.elapsed}");
}

update(HttpRequest req) async {
  var dataMap = await _decodePostBody(req);

  // { timestamp: time, sources: {name : content}}
  auditor.push(new SourceEdit(dataMap["timestamp"], dataMap["sources"]));
}

notifyWait(HttpRequest req) async {
  var dataMap = await _decodePostBody(req);

  // { timestamp: time, waitTime: 2}
  auditor.push(new PauseEvent(dataMap["timestamp"], dataMap["waitTime"]));

  req.response..writeln("notifyWait: ${uptime.elapsed}");
}

Future<Map> _decodePostBody(HttpRequest req) async {
  if (req.method != "POST") throw "Updates must use POST";

  var jsonString = await req.transform(UTF8.decoder).join();
  var dataMap = JSON.decode(jsonString);

  return dataMap;
}
