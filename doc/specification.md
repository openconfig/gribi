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
 * `Get` - a server streaming RPC which can be used by a client to retrieve the
   current set of installed gRIBI entries.
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


## 4.2 The `Get` RPC

## 4.2.1 `Get` semantics
* Contains ACKed entries installed by any client
* Performance expectations - repeated and reconciliation
* Relationship to `openconfig-aft` telemetry
* If the specified network instances have no installed gRIBI objects, return an empty list instead of an error.

## 4.3 The `Flush` RPC
* Modes of operation - emergency client vs. elected master.
* override behaviours