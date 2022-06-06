# gRIBI: gRPC Routing Information Base Interface

**Contributors:** {robjs,nflath}@google.com, {nandan,prakash}@arista.com  
**Version**: 1.0.0  
**Last Update**: 2021-11-29  

# 1 Introduction

This document defines the specification for the gRPC Routing Information Base Interface (gRIBI). gRIBI is a gRPC-based protocol for injecting routing entries
to a network device.

gRIBI is a service that is presented by a network device (referred to as the
server, or target) throughout this document, and interacted with by an external
process, referred to as the client in this document, which may be an element of
an SDN controller.

This document serves as a specification for the gRIBI protocol.

# 2 Data Model
Uses AFT OC model.

## 2.1 `NextHopGroup`

* `BackupNextHopGroup` operation - when to use backup vs. primary
* Weights - expectations for quantisation

## 2.2 `NextHop`
`
* Validation of next-hops
* resolution outside of gRIBI

# 3 Encryption, Authentication and Authorization.

TLS

# 4 Service Definition

The gRIBI service is defined as a single gRPC service, with three RPCs:

 * `Modify` - a bidirectional stream RPC which is used by the client to inject
   routing entries to the server - each part of an individual operation. The 
   server responds asynchronously to these operations with an acknowledgement
   mode, based on the operating mode of the RPC.
 * `Get` - used by clients to retrieve the current set of installed gRIBI entries.
 * `Flush` - a unary RPC that is used as a low-complexity means to remove
   entries from a server.

## 4.1 The `Modify` RPC

High-level description of `Modify` semantics.

* `ADD`
  * repeated `ADD` translates to `MODIFY`
* `MODIFY`
  * must fail if referenced object does not exist.
* `DELETE`
  * error handling for missing entries
  * error handling for forward references

### 4.1.1 Life cycle of a modify operation

Starts when a client creates it, and ends when the device either succeeds or returns failure of the operation. 

### 4.1.2 Forward References

* Ability to NACK forward references
* Server ability for resolving forward references is not required.
* Client's responsibility to send AFTOperations in correct order.

### 4.1.3 Session Negotiation

* Message flow
  * Must be the first message.
  * Client sends `params`, server responds with if acceptable or not.
* Semantics of each field in `params`.

### 4.1.4 Redundancy Modes

* `ALL_PRIMARY`
  * Means to determine which entry is master.
* `SINGLE_PRIMARY`
  * Expectations on `election_id`
  * Behaviours with invalid election IDs
  * Failover behaviors. Upon discovering client failover, the device SHOULD cancel pending AFTOperations from the previous master. Results for AFTOperations from the previous master MUST NOT be sent to the acquiring new master.

### 4.1.5 `election_id` semantics

* Updates
  * client sends modify request specifying only `election_id`, server stores
* In operations
  * client specifies `election_id` in operation.
  * behaviours when negative cases do not match.

### 4.1.6 Persistence modes

* `PRESERVE`
  * across client connections - reconciliation requirement for a client.
  * hardware state preservation requirement
  * software state preservation
    * across daemon failures
    * across control-plane failovers
    * unrecoverable failures
* `DELETE`
   * client liveliness
   * potential gRPC keepalives

### 4.1.7 Acknowledging Operations

* FIB ACK vs. RIB ACK
* When an ACK is sent to the client.
* NACK cases:
  * semantically invalid
  * hardware failure
  * missing entry for `DELETE`
* coaelscion - must ACK every operation ID
* acknowledging entries in the presence of other protocol routes.

### 4.1.8 Timestamping operations.

### 4.1.9 About gRIBI Server Caching
gRIBI server implementation is not required to cache all installed objects.
Implications:
  * When a VRF is removed (e.g. accidentally by user via cli):
    * The device is not required to maintain gRIBI objects in the FIB or RIB.
    * Get() or Flush() should return failed (because the VRF is no longer there)
    * When the VRF is added back, the server is not required to restore all the gRIBI objects by itself.


## 4.2 `Get`

The `Get` RPC is a server streaming RPC for clients to retrieve the current set of installed gRIBI entries. The `Get` RPC is typically used for reconcilation between a client and a server, or for periodical consistency checking by clients.

A client sends a `GetRequest` message specifying the target network instance and gRIBI entry type. The device processes the request and responds a stream of `GetResponse` messages that contain the set of currently installed gRIBI entries by any client. Once all entries have been sent, the server should close the RPC.

### 4.2.1 `GetRequest` message

`GetRequest` message MUST have both `network_instance` and `aft` populated by client.
* If `network_instance` is nil or `network_instance.name` is en empty string, the server should close the `Get` RPC with the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `INVALID_ARGUMENT`.
* If `aft` is set to `ALL`, the device should return all installed gRIBI entries in the specified network instance.
* If `aft` is set to a specific `AFTType`, the device should return all installed gRIBI entries of the specified type in the specified network instance.
* If `aft` is set to a specific `AFTType` that's not supported by the device, , the device should close the `Get` RPC with the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `UNIMPLEMENTED`.

### 4.2.2 `GetResponse` message

A `GetResponse` contains a list of `AFTEntry` messages. A `AFTEntry` message represents an installed gRIBI entry (the data model is defined in x.y.z) and its programming status (`rib_status` and `fib_status`).
* `rib_status` indicates the programming status of the gRIBI entry in RIB. The value should be either `PROGRAMMED` or `NOT_PROGRAMMED`.
* `fib_status` indicates the programming status of the gRIBI entry in FIB. 
  * When the session parameter is `ack_type` = `RIB_ACK`, it's optional for the device to keep track of FIB programming status of each gRIBI entry. Therefore, this field MAY be set to `UNAVAILABLE`.
  * When the session parameter is `ack_type` = `RIB_AND_FIB_ACK`, the value should be either `PROGRAMMED` or `NOT_PROGRAMMED`.

If the specified network instances have no installed gRIBI objects, the device should return an empty list of `AFTEntry` and then close the RPC with the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `OK`.

## 4.3 The `Flush` RPC
* Modes of operation - emergency client vs. elected master.
* override behaviours