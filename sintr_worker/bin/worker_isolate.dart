// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:gcloud/storage.dart';
import 'package:sintr_common/logging_utils.dart' as logging;
import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;

var PROJECT = 'sintr-994';

final _log = new logging.Logger("worker_isolate");

main(List<String> args, SendPort sendPort) {

  logging.setupLogging();
  _log.fine("args: $args");

  config.configuration = new config.Configuration(PROJECT,
  cryptoTokensLocation: "${config.userHomePath}/Communications/CryptoTokens");

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((msg) async {
    sendPort.send(await _protectedHandle(msg));
  });
}

Future<String> _protectedHandle(String msg) async {
  try {
    // Unpack arguments
    var inArgs = JSON.decode(msg);
    _log.finest("inArgs: $msg");

    String key = inArgs["key"];
    String value = inArgs["value"];

    var response = await map(key, value);

    _log.finest("response: $response");
    return JSON.encode(response);
  } catch (e, st) {
    _log.fine("Execution erred. $e \n $st \n");
    _log.fine("Input data: $msg");
    return JSON.encode({});
  }
}

// Sample extractor

Future<Map<String, List<String>>> map(String k, String v) async {
  Map<String, List<String>> retData = new Map<String, List<String>>();

  retData["ErringFiles"] = [];
  retData["Noti"] = [];

  var client = await auth.getAuthedClient();
  _log.finest("Client acquired");

  var storage = new Storage(client, "sintr-994");
  _log.finest("Storage acquired");

  await for (String ln in storage.bucket("sintr-sample-test-data")
     .read(k)
    .transform(UTF8.decoder)       // Decode bytes to UTF8.
    .transform(new LineSplitter())) // Convert stream to individual lines.
  {
    if (!ln.startsWith("~")) continue;

    String timeStr = ln.split(':')[0].split("~")[1];

    if (ln.contains('Noti:{"event"::"server.error"')) {
      retData["ErringFiles"].add(k);
    }

    if (ln.contains("Noti")) {
      retData["Noti"].add(timeStr);
    }
  }

  return retData;

}