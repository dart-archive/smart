// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' as io;
import 'dart:convert';
import 'dart:async';

main(List<String> args) async {
  if (args.length != 1) {
    print("Clones the repos into the current working directory");
    print("Usage: dart clone_repos_from_json.dart [path of dart_repos.json]");
  }

  io.Directory startingDir = io.Directory.current;

  List<String> jsonFileContents = new io.File(args[0]).readAsLinesSync();

  for (String ln in jsonFileContents) {
    if (ln.startsWith("[")) {
      var lst = JSON.decode(ln);
      for (var item in lst) {
        String url = item['repository_url'];

        List<String> repoComponents = url.split('/');

        String repoName = repoComponents.last;
        String orgName = repoComponents[repoComponents.length - 2];

        String cloneDir = "${orgName}_${repoName}";

        print("Repo: $repoName");

        if (new io.Directory(cloneDir).existsSync()) {
          print("$url already exists, skipping");
          continue;
        }

        // Check the status on the URLs, many repos return 404
        bool urlOk = await _urlOK(url);
        if (!urlOk) continue;

        new io.Directory(cloneDir).createSync();
        io.Directory.current = new io.Directory(cloneDir);

        print("Cloning into: $url");

        var proc = await io.Process.run('git', ['clone', url])
            .timeout(new Duration(seconds: 30), onTimeout: () {
          print("Timeout");
        });

        print(proc?.stdout);
        print(proc?.stderr);
        io.Directory.current = startingDir;
      }
    }
  }
}

Future<bool> _urlOK(String url) async {
  io.HttpClient client = new io.HttpClient();
  io.HttpClientRequest request = await client.getUrl(Uri.parse(url));
  io.HttpClientResponse response = await request.close();
  int statusCode = response.statusCode;
  response.drain();
  print("$url $statusCode");
  return (statusCode / 100).floor() == 2;
}
