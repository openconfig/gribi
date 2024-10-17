# How to rebuild the gRIBI protos on OSX

## Install dependencies

* brew install coreutils
* brew install protoc-gen-go-grpc
* brew install protoc-gen-go
* go install github.com/openconfig/ygot/proto_generator@latest

## Update AFT yang

* Copy the YANG model files for openconfig public AFTs
* Add deviations as needed to gribi-aft.yang
* Run update_schema.sh
* Run generate_proto.sh
* Run check-updated.sh to review for any unexpected changes
