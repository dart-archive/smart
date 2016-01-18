# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Upload the sample source ready for execution
# Should be run from the smart root folder
set -e

# Factor this so that it doesn't rely on specific folder layout
dart ~/GitRepos/sintr_common/bin/uploadSource.dart liftoff-dev liftoff-dev-source test_worker.json ~/GitRepos/smart
