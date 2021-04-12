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

$GOPATH/bin/proto_generator \
	-path=yang,yang/deps \
	-output_dir=proto -compress_paths -generate_fakeroot -fakeroot_name=device \
	-package_name=gribi_aft -exclude_modules=ietf-interfaces,openconfig-interfaces \
	-base_import_path="github.com/openconfig/gribi/proto" \
	-go_package_base="github.com/openconfig/gribi/proto" \
	yang/gribi-aft.yang
$GOPATH/bin/generator \
	-path=yang,yang/deps \
	-output_file=oc/oc.go -package_name=oc -generate_fakeroot -fakeroot_name=device \
	-exclude_modules=ietf-interfaces,openconfig-interfaces \
	yang/gribi-aft.yang

echo -e "$(cat scripts/data/apache-short)\n\n$(cat oc/oc.go)" > oc/oc.go

find proto -type d -mindepth 1 | while read l; do (cd $l && go generate); done
