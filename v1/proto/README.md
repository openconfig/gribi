# gRIBI Protobuf Definitions

gRIBI consists of a service definition (stored in `service`),
and a data model of the set of AFTs that are altered by the
service. The AFT definitions are auto-generated from the
OpenConfig AFT YANG schema.

The gRIBI service is stored in a package named according
to the major version of the protocol - specifically
`gribi.v1` for the first major version. Within a major
revision no backwards incompatible changes are made to
the service definition or AFT models according to standard
protobuf backwards compatibility rules.
