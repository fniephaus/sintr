// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library sintr_worker_lib.session_info;

import 'dart:async';
import 'dart:convert';

import 'package:sintr_worker_lib/instrumentation_transformer.dart';

final SESSION_ID = 'sessionId';
final CLIENT_START_TIME = 'clientStartTime';
final UUID = 'uuid';
final CLIENT_ID = 'clientId';
final CLIENT_VERSION = 'clientVersion';
final SERVER_VERSION = 'serverVersion';
final SDK_VERSION = 'sdkVersion';

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
  return {
    SESSION_ID: sessionId,
    CLIENT_START_TIME: data[0].substring(1),
    UUID: data[2],
    CLIENT_ID: data[3],
    CLIENT_VERSION: data[4],
    SERVER_VERSION: data[5],
    SDK_VERSION: data[6]
  };
}
