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

The gRIBI service is a single gRPC service currently defined in [`gribi.proto`](https://github.com/openconfig/gribi/blob/master/v1/proto/service/gribi.proto). It includes three RPCs:

 * `Modify` - used by the clients to modify the device's RIB.
 * `Get` - a server streaming RPC which can be used by a client to retrieve the
   current set of installed gRIBI entries.
 * `Flush` - a unary RPC that is used as a low-complexity means to remove
   entries from a server.

IANA has reserved [TCP port 9340](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=9340#Google_Networking) for gRIBI service.

## 4.1 `Modify`

The `Modify` provides a bidirectional streaming RPC for clients to modify the device's RIB. A client sends `ModifyRequest` messages that contains a set of `AFTOperation` messages to the device. The device processes the received requests and responds them asynchronously.

### 4.1.1 Client-Server Session Neogotiation

A gRIBI client is identified by gRPC connection, i.e., if a connection drops and reconnect with the same `election_id` value, it will be considered as another client.

Before a client starting sending `AFTOperations`, it should reach agreement with the device regarding the following session parameters
* Redundancy Mode (defined in x.y.z)
* Persistent Mode (defined in x.y.z)
* Acknoledge Mode (defined in x.y.z)

A client starts the neogotiation process by sending the first `ModifyRequest` message with only `params` populated. `params` MUST NOT be sent more than once during the lifetime of the RPC session. All clients MUST send the same values of all the attributes of `params`. If the device can process and support the requesed parameters, it should respond with `ModifyResponse` that has `session_params_result.status = OK`. Otherwise, the device should close the `Modify` RPC and set the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) per the following scenarios:
* If any of the requested parameter is not fully implemented, set `Status.code` to `UNIMPLEMENTED`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `UNSUPPORTED_PARAMS`.
* If the requested `params` does not match parameters of other live `Modify` RPC sessions, set the `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `PARAMS_DIFFER_FROM_OTHER_CLIENTS`.
* If other cases, set the `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with appropriate `reason` populated.

It is possible that the client skips the negotiation step. In this case, the first `ModifyRequest` message from the client contains `AFTOperations` and does not populate `params`. The device will assume defautl parameters are requested by the client. If any of the default parameters is not supported by the device, the device should close the `Modify` RPC upon receiving the first `ModifyRequest` message, and the device should set the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) to `UNIMPLEMENTED`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `UNSUPPORTED_PARAMS`. The following are the default parameters:
* `redundancy` = `ALL_PRIMARY`.
* `persistence` = `DELETE`
* `ack_type` = `RIB_ACK`

### 4.1.2 Election ID

Election ID helps the device to consume the election resullt in `SINGLE_PRIMARY` mode (redundancy mode is defined in x.y.z).

Election ID should only be used in `SINGLE_PRIMARY` mode. If the agreed redundancy mode is `ALL_PRIMARY`, but a client populates either `ModifyRequest.election_id` or `AFTOperation.election_id`, the device should close the `Modify` RPC and set `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `ELECTION_ID_IN_ALL_PRIMARY`.

There are two fields for election ID.
* `ModifyRequest.election_id` is to indicate the clients election result. It should only be populated when the client's election ID changed after an election result (election is defined in x.y.z).
* `AFTOperation.election_id` is consumed by the server to determine whether to process the AFTOperation. In `SINGLE_PRIMARY` mode, an `AFTOperation` message should always have the `election_id` populated.

In `SINGLE_PRIMARY` mode, the device processes the `AFTOperation` only if all the following conditions met:
* The `AFTOperation.election_id` is equal to the `ModifyRequest.election_id` last advertised by the client.
* The `AFTOperation.election_id` has the highest value amongst all the election IDs that the device knows about, i.e., the client is the primary client.

Otherwise, the device discards the `AFTOperation` and returns a `ModifyResponse` with `AFTResult` = `FAILED`.

`ModifyRequest.election_id` MUST be non zero. When a device receives an value of 0, it should close the `Modify` RPC and set `Status.code` to `INVALID_ARGUMENT`. The election ID can only be increased monotonically by a client during a RPC session. This simplifies server implementation.

### 4.1.3 AFTOperation

RIB modification desire sent by clients are carried by a set of `AFTOperation` messages. Three types of operations are supported:
* `ADD` - creates an entry. If the entry already exists in the specified RIB table, the `ADD` SHOULD be treated as replacing the existing entry with the entry specified in the operation.
* `REPLACE` - replaces an existing entry in the specified RIB table. It MUST fail if the entry does not exist. A replace operation should contain all of the relevant fields, such that existing entry is completely replaced with the specified entry.
* `DELETE` - removes an entry from the specified RIB table, it MUST fail if the entry does not exist.

`AFTOperation` is identified by its `id`.  The `AFTOperation.id` should be unique per `Modify` RPC session. It's the client's responsibility to gurrantee the uniqueness during a `Modify` RPC session.

#### 4.1.3.1 AFTOperation Validation
* minimum validation.
* `election_id` check.

#### 4.1.3.2 Forward References

* Ability to NACK forward references
* Server ability for resolving forward references is not required.
* Client's responsibility to send AFTOperations in correct order.

#### 4.1.3.3 AFTOperation Response

Each AFTOperation should be responded individually.

* FIB ACK vs. RIB ACK
* When an ACK is sent to the client.
* NACK cases:
  * semantically invalid
  * hardware failure
  * missing entry for `DELETE`
* coaelscion - must ACK every operation ID
* acknowledging entries in the presence of other protocol routes.

#### 4.1.3.4 Life cycle of an `AFTOperation`

The life of an AFTOperation starts when a client creates it, and ends in the following scenarios:
* The device failed to program the operation into RIB. // Return `FAILED`.
* `ack_type` = `RIB_ACK`, the device programmed the operation into RIB successfully. // Return `RIB_PROGRAMMED`.
* `ack_type` = `RIB_AND_FIB_ACK`, the device programmed the operation into FIB successfully. // Return `FIB_PROGRAMMED`.
* `ack_type` = `RIB_AND_FIB_ACK`, the device has successfully programmed the operation into RIB but failed to program it into FIB. // Return `FIB_FAILED`. Note that this is regardless if a device is going to retry the FIB programming or not. The client can promptly send another `AFTOperations` for explicit behaviors (e.g. `ADD` for retry, and `DELETE` for stopping retry).
* The existing gRPC session is disconnected/canceled. All pending `AFTOperations` from the client should be cancelled.
* The device has discovered a failover of the master client (see xxx for more details).

Only during the life cycle should the device keep the client updated via `AFTResult` message. 

#### 4.1.3.5 AFTOperation Error Handling

Should not close the RPC session due to errors encountered in an AFTOperation. Invalid AFTOperations should be responded to with failures within the stream.

### 4.1.4 Redundancy Mode

`Modify` can operate in one of the following redundancy mode:
* `SINGLE_PRIMARY`: The device accepts `AFTOperations` from the primary client only. The device discards `AFTOperations` received from non-primary client and responses error (see x.y.x for details). 
* `ALL_PRIMARY`: The device accepts AFTOperations from all clients. [Place holder for more details]

#### 4.1.4.1 Client Election In `SINGLE_PRIMARY`

gRIBI server does not paticipate in the election process, rather it consumes the election result. Election result is reflected in the `ModifyRequest.election_id` sent by clients. gRIBI server treats the client of the highest election ID as the primary client.

When a client's election ID changed, the client should send a `ModifyRequest` with only the `ModifyRequest.election_id` populated. The device should respond with a `ModifyResponse` that has only the `election_id` field populated. The `ModifyResponse.election_id` by the server should be the highest election ID that the device has learnt from any client.

If the `ModifyRequest.election_id` sent by a client matches the previous highest value, the newer client is considered primary. This allows for a client to reconnect
without an external election having taken place. It is gRIBI clients' responsibility to avoid more than one `Modify` RPC sessions that are of the same highest Election ID, i.e., "dual-primary" situation in a `SINGLE_PRIMARY` mode.

#### 4.1.4.2 Client Failover In `SINGLE_PRIMARY`
Failover happnes when a new client connects with `ModifyRequest.election_id` equals to, or greater than, the previous highest value that learnt by the server from any client.

Upon discovering a failover, the device:
* SHOULD stop processing pending `AFTOperations` that were sent by the previous primary.
* MUST not send responses for `AFTOperations` of the previous primary to the acquiring-primary.

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