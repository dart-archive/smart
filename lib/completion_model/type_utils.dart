// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library smart.completion_model.type_utils;

// TODO(lukechurch): This is a temporary home for this code
// it should get moved into the analzyer as soon as it is
// being built directly from dart

import 'package:analyzer/src/generated/element.dart';

class TypeUtils {
  static String qualifiedName(Element e) {
    if (e == null) return "null";

    var owner = e.enclosingElement;
    if (owner is Element) {
      return "${qualifiedName(owner)}:${e.name}";
    }
    return e.name;
  }
}
