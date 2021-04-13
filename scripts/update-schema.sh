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

if [ -z $SRCDIR ]; then
	THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	SRC_DIR=${THIS_DIR}/..
fi

proto_generator \
	-path=${SRC_DIR}/yang,${SRC_DIR}/yang/deps \
	-output_dir=${SRC_DIR}/proto -compress_paths -generate_fakeroot -fakeroot_name=device \
	-package_name=gribi_aft -exclude_modules=ietf-interfaces,openconfig-interfaces \
	-base_import_path="proto" \
	-go_package_base="github.com/openconfig/gribi/proto" \
	${SRC_DIR}/yang/gribi-aft.yang
generator \
	-path=${SRC_DIR}/yang,${SRC_DIR}/yang/deps \
	-output_file=${SRC_DIR}/oc/oc.go -package_name=oc -generate_fakeroot -fakeroot_name=device \
	-exclude_modules=ietf-interfaces,openconfig-interfaces \
	${SRC_DIR}/yang/gribi-aft.yang

echo -e "$(cat ${SRC_DIR}/scripts/data/apache-short)\n\n$(cat ${SRC_DIR}/oc/oc.go)" > ${SRC_DIR}/oc/oc.go
