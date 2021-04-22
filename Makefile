# gRIBI Makefile
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

generate:
	$(ROOT_DIR)/scripts/update-schema.sh
	$(ROOT_DIR)/scripts/generate-proto.sh
clean:
	find proto -name *.pb.go -exec rm {} \;
deps: generate

