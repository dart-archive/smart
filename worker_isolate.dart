// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:gcloud/storage.dart' as storage;
import "package:googleapis_auth/auth_io.dart";
import 'package:path/path.dart' as path;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/bucket_utils.dart';
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/logging_utils.dart' as log;

import 'package:smart/completion_model/analyse_path.dart';

const PROJECT_NAME = "liftoff-dev";
const PATH_NAME = "data_working";

const PUB_GET_TIMEOUT = const Duration(minutes: 5);

Future main(List<String> args, SendPort sendPort) async {
  log.setupLogging("smart:worker_isolate");

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  log.trace("Begin _protectedHandle: $msg");
  var client;
  try {
    var inputData = JSON.decode(msg);
    String bucketName = inputData[0];
    String objectPath = inputData[1];

    // Cloud connect
    config.configuration = new config.Configuration(PROJECT_NAME,
        cryptoTokensLocation:
            "${config.userHomePath}/Communications/CryptoTokens");
    client = await auth.getAuthedClient();

    log.trace("Client acquired, beginning processFile");

    var results =
        await processFile(client, PROJECT_NAME, bucketName, objectPath);

    return JSON
        .encode({"result": results, "input": "gs://$bucketName/$objectPath",});
  } catch (e, st) {
    log.info("Message proc erred. $e \n $st");
    log.info("About to close client");

    if (client != null) client.close();
    log.debug("Input data: $msg");
    return JSON.encode({"error": "${e}", "stackTrace": "${st}"});
  }
}

Future processFile(AuthClient client, String projectName, String bucketName,
    String cloudFileName) async {
  log.trace("processFile $projectName $bucketName $cloudFileName");

  String homeDir = Platform.environment["HOME"];
  String workingPath = homeDir + "/" + PATH_NAME;
  log.trace("workingPath: $workingPath");

  Directory workingDirectory = new Directory(workingPath);
  if (workingDirectory.existsSync()) {
    log.info("WorkingDirectory: ${workingDirectory.path} exists, deleting");
    workingDirectory.deleteSync(recursive: true);
  }
  log.info("Creating: ${workingDirectory.path}");
  workingDirectory.createSync();

  var sourceStorage = new storage.Storage(client, projectName);

  log.info("Downloading $bucketName/$cloudFileName");

  await downloadFile(
          sourceStorage.bucket(bucketName), cloudFileName, workingDirectory)
      .timeout(new Duration(seconds: 300));

  log.info("Downloaded. Decompressing");
  workingDirectory = new Directory(workingPath);

  for (var f in workingDirectory.listSync(recursive: true)) {
    log.info("Testing: ${f.path}");

    if (f.path.endsWith(".tar.gz")) {
      // Pub files need to be ungziped manually
      log.info("Running ungzip");
      ProcessResult gzipResult = await Process.run("gzip", ['-d', f.path]);
      log.info(
          "Ungzip finished, "
          "stdout:\n${gzipResult.stdout}\nstderr:${gzipResult.stderr}");

      String decompressedPath = f.path.substring(0, f.path.length - 3);

      log.info("Running untar");
      ProcessResult result = await Process.run(
          "tar", ['xvf', decompressedPath, '-C', workingDirectory.path]);
      log.info(
          "Untar finished, stdout:\n${result.stdout}\nstderr:${result.stderr}");
      new File(decompressedPath).deleteSync();
      log.info("Original deleted");
    }
  }

  for (var f in workingDirectory.listSync(recursive: true)) {
    if (f.path.toLowerCase().endsWith("pubspec.yaml")) {
      log.info("Running pub get");
      await _pubUpdate(f.path);
      log.info("Pub get completed");
    }
  }

  log.info("About to analyse folder: ${workingDirectory.path}");

  var results = await analyseFolder(workingDirectory.path);
  // var results = [workingDirectory.path];

  log.info("Cleaning up");
  log.info("Deleting working directory");

  workingDirectory.deleteSync(recursive: true);
  log.info("Deleted working directory");

  return results;
}

_pubUpdate(String pubspecPathsToUpdate) async {
  Directory orginalWorkingDirectory = Directory.current;

  String fullName = pubspecPathsToUpdate;
  //TODO: Path package
  Directory.current = path.dirname(fullName);

  log.trace("In ${Directory.current.toString()} about to run pub get");
  Process pubProc = await Process.start("pub", ["get"], runInShell: true);
  pubProc.stderr.drain();
  pubProc.stdout.drain();

  log.trace("Waiting for exit code");
  pubProc.exitCode.timeout(PUB_GET_TIMEOUT, onTimeout: () {
    log.trace("Pub get timeout, sending SIGKILL");
    bool result = pubProc.kill(ProcessSignal.SIGKILL);
    log.trace("SIGKILL: $result");
  });
  log.trace("Pub get concluded");

  Directory.current = orginalWorkingDirectory;
}
