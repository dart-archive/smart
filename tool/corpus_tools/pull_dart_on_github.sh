# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This script pulls the repos from the GitHub timeline
# it requires dart to be in the path

set -e

NOW=$(date +"%Y-%m-%d-%H-%M-%S")
mkdir -p ~/github/corpus/$NOW/src

bq query --format=json --max_rows 100000 'SELECT repository_url FROM [githubarchive:github.timeline] WHERE repository_language = "Dart" GROUP BY repository_url' > ~/github/corpus/$NOW/dart_repos_timeline.json

cd ~/github/corpus/$NOW/src
dart clone_repos_from_json.dart ~/github/corpus/$NOW/dart_repos_timeline.json

cd ~
tar -czf dart-github-corpus-$NOW.tar.gz ~/github/corpus/$NOW
gsutil mv -n dart-github-corpus-$NOW.tar.gz gs://dart-usage-corpus

rm -rf ~/github/corpus/$NOW
