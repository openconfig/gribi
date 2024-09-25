# How to rebuild the gribi protos

## Install dependencies

* brew install coreutils
* http://github.com/openconfig/ygot for proto_generator
* build ygot proto_generator

## Update aft yang

* Add deviations as needed to gribi-aft.yang
* Run update_schema.sh
* Run generate_proto.sh
* Run check-updated.sh to review for any unexpected changes
