# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Halt on the first error
set -e

# echo "Delete logs"
gsutil -m rm gs://liftoff-dev-worker-logs/*

echo "Deploying Client code"
./tool/sintr/upload_src.sh

echo "Creating tasks"
dart tool/sintr/create_tasks.dart
