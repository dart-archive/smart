// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library auditor;

import 'dart:convert';

void main() {
  var a = new Auditor();
  a.push(new SourceEdit(10, {"main" : "a"}));
  a.push(new SourceEdit(20, {"main" : "b"}));
  a.push(new SourceEdit(5, {"main" : "c"}));
  a.push(new SourceEdit(6, {"main" : "d"}));

  print (a.serialiseSession());
}

class Auditor {
  List<Event> timeLine = [];

  push(Event e) {
    if (timeLine.isEmpty ||
       timeLine.last.time < e.time)
    {
      timeLine.add(e);
      return;
    }

    if (e.time < timeLine[0].time) {
      timeLine.insert(0, e);
      return;
    }

    int index = indexForTime(e.time) + 1;
    assert(index != -1 && index <= timeLine.length);

    timeLine.insert(index, e);
  }

  Map<String, String> sourceCodeAt(int time) {
    int index = indexForTime(time);

    while (index >= 0) {
      var edit = timeLine[index] as SourceEdit;
      if (edit != null) return edit.source;
      index--;
    }
    return {};
  }

  int indexForTime(int timeStamp) {
    if (timeLine.length == 0 || timeLine[0].time > timeStamp ) return -1;
    // TODO: Binary search
    for (int i = 0; i < timeLine.length; i++) {
      if (timeLine[i].time > timeStamp) return i - 1;
      if (timeLine[i].time == timeStamp) return i;
    }
    return timeLine.last.time;
  }

  serialiseSession() => JSON.encode(timeLine);
}

class Event {
  int time;

  Event(this.time);
}

class SourceEdit extends Event {
  Map<String, String> source;
  String message;

  SourceEdit(time, this.source, {this.message}) : super(time);

  toJson() {
    return JSON.encode({
      "time" : time,
      "sources" : source,
      "type" : "SourceEdit",
      "message" : message
    });
  }
}

class PauseEvent extends Event {
  int waitTime;

  PauseEvent(time, this.waitTime) : super(time);

  toJson() {
    return JSON.encode({
      "time" : time,
      "type" : "PauseEvent",
      "waitTime" : waitTime
    });
  }
}
