# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

import os
import re
import shutil
import subprocess

import requests

PACKAGE_URL = re.compile(r'http://pub.dartlang.org/packages/(\w+).json')

PUBSPEC = '''
name: %s
dependencies:
  %s: %s
'''

ARCHIVE_URL = "https://commondatastorage.googleapis.com/pub.dartlang.org/packages/{}-{}.tar.gz"

package_urls = []

# Download the full list of package names.
print 'Downloading package lists:'
url = 'http://pub.dartlang.org/packages.json'
while True:
  print '-', url
  data = requests.get(url).json()
  for package in data['packages']:
    package_urls.append(package)
  url = data['next']
  if not url: break

print
print 'Found', len(package_urls), 'packages'

if os.path.exists('out'):
  shutil.rmtree('out')
os.mkdir('out')

# Download the archive of the most recent version of each package.
for package_url in package_urls:
  data = requests.get(package_url).json()

  name = data['name']
  version = data['versions'][-1]

  print name, version

  # Download the archive.
  archive_url = ARCHIVE_URL.format(name, version)
  tar_file = 'out/{}-{}.tar'.format(name, version)
  with open(tar_file, 'wb') as file:
    file.write(requests.get(archive_url).content)

  # Extract it.
  extract_dir = 'out/{}-{}'.format(name, version)
  os.mkdir(extract_dir)
  subprocess.call(['tar', '-xf', tar_file, '-C', extract_dir])
