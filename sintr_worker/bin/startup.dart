// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';


import 'package:crypto/crypto.dart';
import 'package:gcloud/pubsub.dart' as gPubSub;

import 'package:sintr_common/auth.dart' as auth;
import 'package:sintr_common/configuration.dart' as config;
import 'package:sintr_common/pubsub_utils.dart' as ps;
import 'package:logging/logging.dart' as logging;

final _log = new logging.Logger("worker");
String workerFolder;
const START_NAME = "worker_isolate.dart";


main(List<String> args) async {
  if (args.length != 3) {
    print("Usage: dart startup.dart project_name control_channel worker_folder");
    print (args);
    exit(1);
  }

  logging.Logger.root.level = logging.Level.FINE;
  logging.Logger.root.onRecord.listen((logging.LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  _log.finest(args);

  String projectName = args[0];
  String controlChannel = args[1];
  workerFolder = args[2];

  config.configuration = new config.Configuration(projectName,
  cryptoTokensLocation: "/Users/lukechurch/Communications/CryptoTokens");

  var client = await auth.getAuthedClient();
  var pubsub = new gPubSub.PubSub(client, projectName);

  String topicName = "$controlChannel-topic";
  String subscriptionName = "$controlChannel-subscription";


  // Need to ensure that the topic is created to ensure that the
  // subscription doesn't fail.
  gPubSub.Topic topic = await ps.getTopic(
    topicName, pubsub);

  gPubSub.Subscription subscription = await ps.getSubscription(
      subscriptionName, topicName, pubsub);

  while (true) {
    gPubSub.PullEvent event = await subscription.pull();
    if (event != null) {
      _handleEvent(event);
      await event.acknowledge();
    } else {
      _log.info("${new DateTime.now()}: null event notification");
    }
  }
}

_handleEvent(gPubSub.PullEvent event) async {
  _log.finest("${event.message.asString}");

  try {
    var msgMap = JSON.decode(event.message.asString);
    var codeMap = msgMap["codeMap"];
    _ensureCodeIsInstalled(codeMap);
    var data = msgMap["data"];
    _log.fine("Sending: $data");
    sendPort.send(data);
    _log.fine("${new DateTime.now()}: Resonse: ${await resultsStream.first}");
  } catch (e, st) {
    print (e);
  }
}

_ensureCodeIsInstalled(Map<String, String> codeMap) {
  String sha = _computeCodeSha(codeMap);

  if (sha == shaCodeRunningInIsolate) {
    _log.finest("Code already installed: $sha");
    // The right code is already installed and hot
    return;
  }

  // Shutdown the existing isolate
  _log.finest("Killing existing isolate");
  if (isolate != null) {
    isolate.kill();
    isolate = null;
  }

  // Write the code to the folder
  for (String sourceName in codeMap.keys) {
    new File("$workerFolder$sourceName").writeAsStringSync(codeMap[sourceName]);
  }
  _setupIsolate("$workerFolder$START_NAME");

  _log.fine("Isolate started with sha: $sha");
  shaCodeRunningInIsolate = sha;
}

/// Compute a sha of the source, canonicallised using the order
/// of the file names.
String _computeCodeSha(Map<String, String> codeMap) {
  var sortedKeys = codeMap.keys.toList()..sort();

  StringBuffer sourceAggregate = new StringBuffer();
  for (String key in sortedKeys) {
    sourceAggregate.writeln(key);
    sourceAggregate.writeln(codeMap[key]);
  }

  SHA1 sha1 = new SHA1();
  sha1.add(sourceAggregate.toString().codeUnits);
  return CryptoUtils.bytesToHex(sha1.close());
}

// Worker properties.
SendPort sendPort;
ReceivePort receivePort;
Isolate isolate;

StreamController resultsController;
Stream resultsStream;
String shaCodeRunningInIsolate;

_setupIsolate(String startPath) async {
  _log.fine("_setupIsolate: $startPath");
  sendPort = null;
  receivePort = new ReceivePort();
  resultsController = new StreamController();
  resultsStream = resultsController.stream.asBroadcastStream();

  _log.finest("About to bind to recieve port");
  receivePort.listen((msg) {
    if (sendPort == null) {
      _log.finest("send port recieved");
      sendPort = msg;
    } else {

      resultsController.add(msg);
    }
  });

  isolate =
    await Isolate.spawnUri(Uri.parse(startPath), [], receivePort.sendPort);
  _log.info("Worker isolate spawned");
}