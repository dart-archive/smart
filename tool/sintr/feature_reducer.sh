# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Run the feature reducer on a local machine

# This expects to run against the project lift-off-dev
# and to be run from the root of the checkout of smart

BASE_DIR=~/Analysis/smart/features

echo "Setting up folders"

rm -r $BASE_DIR/incoming
mkdir -p $BASE_DIR/incoming

rm -r $BASE_DIR/completion_features
mkdir -p $BASE_DIR/completion_features

echo "Copying features from cloud storage"

gsutil -m cp -r gs://liftoff-dev-results/liftoff-dev-datasources-github-completion-features/* $BASE_DIR/incoming

echo "Renaming feature files"

for file in $(find $BASE_DIR/incoming -name '*.gz')
do
  mv $file $file.json
done

echo "Running completion feature extractor"

dart bin/completion_model/completion_feature_indexer.dart \
  $BASE_DIR/incoming \
  $BASE_DIR/completion_features
