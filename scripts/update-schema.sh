#!/bin/bash

# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Hack to ensure that if we are running on OS X with a homebrew installed
# GNU sed then we can still run sed.
runsed() {
  if hash gsed 2>/dev/null; then
    gsed "$@"
  else
    sed "$@"
  fi
}

# A similar hack for readlink
runreadlink() {
  if hash greadlink 2>/dev/null; then
    greadlink "$@"
  else
    readlink "$@"
  fi
}

if [ -z $SRCDIR ]; then
	THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	SRC_DIR=`runreadlink -m ${THIS_DIR}/..`
fi

# Apply patches to YANG that are within the version
for i in `find ${SRC_DIR}/v1/yang/patches -name *.patch | sort`; do
  patch -b -p1 < $i;
done

proto_generator \
	-path=${SRC_DIR}/v1/yang,${SRC_DIR}/v1/yang/deps \
	-output_dir=${SRC_DIR}/v1/proto -compress_paths -generate_fakeroot -fakeroot_name=device \
	-package_name=gribi_aft -exclude_modules=ietf-interfaces,openconfig-interfaces \
	-base_import_path="v1/proto" \
	-go_package_base="github.com/openconfig/gribi/v1/proto" \
	-consistent_union_enum_names -typedef_enum_with_defmod \
	${SRC_DIR}/v1/yang/gribi-aft.yang \
  ${SRC_DIR}/v1/yang/gribi-augments.yang

# Add licensing to the generated Go code.
RP=`echo ${SRC_DIR} | sed 's/\./\\./g'`

# Replace absolute paths in the protobuf files.
for i in `find ${SRC_DIR} -type f -name "*.proto"`; do
	runsed -i "s;${RP};github.com/openconfig/gribi;g" $i
done

# Revert files to original (pre-patched) state.
for i in `find ${SRC_DIR}/v1/yang -name *.orig`; do
  mv $i `echo $i | sed 's/\.orig//g'`; done
done
