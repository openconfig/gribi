# gRIBI - gRPC Routing Information Base Interface

gRIBI defines an interface via which entries can be injected from an external
client to a network element. The gRIBI interface is defined in the
`proto/service/gribi.proto` - which defines a simple API for adding and removing
routing entries. The RIB entries are described using a protobuf translated
version of the OpenConfig AFT model.

During the initial development phase, the OpenConfig AFT model is forked in this
repo. Changes will be upstreamed following iteration of the design of the API.

A detailed description of the gRIBI protocol can be found in [
docs/motivation.md](https://github.com/openconfig/gribi/blob/master/doc/motivation.md).

## Disclaimer

This is not an official Google product.
