# gRIBI Makefile
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

generate:
	cd ${ROOT_DIR}/proto/gribi_aft/enums && go generate
	cd ${ROOT_DIR}/proto/gribi_aft && go generate
	cd ${ROOT_DIR}/proto/service && go generate
clean:
	find proto -name *.pb.go -exec rm {} \;
deps: generate

