// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_info;

import 'dart:async';
import 'dart:convert';

import 'instrumentation_transformer.dart';

const SESSION_ID = 'sessionId';
const CLIENT_START_TIME = 'clientStartTime';
const CLIENT_START_DATE = "clientStartDate";
const UUID = 'uuid';
const CLIENT_ID = 'clientId';
const CLIENT_VERSION = 'clientVersion';
const SERVER_VERSION = 'serverVersion';
const SDK_VERSION = 'sdkVersion';

Future<Map> readSessionInfo(String sessionId, Stream<List<int>> stream) async {
  String firstLine = await stream
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .transform(new LogItemTransformer())
      .first;
  return parseSessionInfo(sessionId, firstLine);
}

Map parseSessionInfo(String sessionId, String firstLine) {
  var data = firstLine.split(':');

  String clientStartTime = data[0].substring(1);
  var clientStartDate =
      new DateTime.fromMillisecondsSinceEpoch(int.parse(clientStartTime));
  var clientDateString =
      "${clientStartDate.year}-${clientStartDate.month}-${clientStartDate.day}";

  return {
    SESSION_ID: sessionId,
    CLIENT_START_TIME: clientStartTime,
    UUID: data[2],
    CLIENT_ID: data[3],
    CLIENT_VERSION: data[4],
    SERVER_VERSION: data[5],
    SDK_VERSION: data[6],
    CLIENT_START_DATE: clientDateString
  };
}
