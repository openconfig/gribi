# gRIBI: gRPC Routing Information Base Interface

**Contributors:** {robjs,nflath}@google.com, {nandan,prakash}@arista.com  
**Version**: 1.0.0  
**Last Update**: 2021-11-29  

# 1 Introduction

This document defines the specification for the gRPC Routing Information Base Interface (gRIBI). gRIBI is a gRPC-based protocol for injecting routing entries
to an network device. gRIBI implementation on an network device is presented as a service that can be interacted with by an external process, which may be an element of an SDN controller.

Terminology used in this document:
* Device - refers to an network device that presents the gRIBI service.
* Server - refers to the gRIBI server implementation on the device.
* Client - refers to a gRIBI client implementation that is usually running externally to the device.
* gRIBI entry - refers to an entry that can be injected to a network device via gRIBI, e.g., an IPv4 prefix, a next_hop_group, or a next_hop, etc (see the message `AFTOperation.entry`).
* AFT operation - refers to the operation (e.g., add an next_hop) carried in an `AFTOperation` message.
[TODO] update the whole doc with the above defined terminology.

# 2 Data Model

gRIBI uses the [OC (OpenConfig) AFT model](https://github.com/openconfig/public/tree/master/release/models/aft) as an abstracted view of the device RIB. Using the same schema as the OC AFT model simplifies gRIBI injection service as much as possible. It guarantees that injected gRIBI entries are mappable to the existing gNMI `Get` and `Subscribe` RPCs for retrieving and streaming AFT entries.

The YANG model is transformed to Protobuf to be carrried within the payload of gRIBI RPCs. The process of machine translating YANG to Protobuf is implemented in the [ygot](https://github.com/openconfig/ygot) library.

# 3 Encryption, Authentication and Authorization.

TLS

# 4 Service Definition

The gRIBI service is a single gRPC service defined in [`gribi.proto`](https://github.com/openconfig/gribi/blob/master/v1/proto/service/gribi.proto). It includes three RPCs:

 * `Modify` - used by the clients to modify the device's RIB.
 * `Flush` - defined in x.y.z, used by clients to remove gRIBI entries on a device.
 * `Get` - used by clients to retrieve the current set of installed gRIBI entries.

IANA has reserved [TCP port 9340](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=9340#Google_Networking) for gRIBI service.

## 4.1 `Modify`

The `Modify` provides a bidirectional streaming RPC for clients to modify the device's RIB. A client sends `ModifyRequest` messages that contains a set of `AFTOperation` messages to the device. The device processes the received requests and responds them asynchronously.

### 4.1.1 Client-Server Session Negotiation

A gRIBI client is identified by `Modify` RPC sessions, i.e., if a session drops and reconnect with the same `election_id` value, it will be considered as another client.

Before a client starts sending `AFTOperation` messages, it should specify the desired parameters for the session.
* Redundancy Mode (defined in x.y.z)
* Persistent Mode (defined in x.y.z)
* Acknoledge Mode (defined in x.y.z)

A client starts the negotiation process by sending the first `ModifyRequest` message with only `params` populated. `params` MUST NOT be sent more than once during the lifetime of the RPC session. All clients MUST send the same values of all the attributes of `params`. If the device can process and support the requesed parameters, it should respond with `ModifyResponse` that has `session_params_result.status = OK`. Otherwise, the device should close the `Modify` RPC and set the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) per the following scenarios:
* If any of the requested parameter is not fully implemented, set `Status.code` to `UNIMPLEMENTED`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `UNSUPPORTED_PARAMS`.
* If the requested `params` does not match parameters of other live `Modify` RPC sessions, set the `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `PARAMS_DIFFER_FROM_OTHER_CLIENTS`.
* If other cases, set the `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with appropriate `reason` populated.

It is possible that the client skips the negotiation step. In this case, the first `ModifyRequest` message from the client contains `AFTOperations` and does not populate `params`. The device will assume the default parameters are requested by the client. If any of the default parameters is not supported by the device, the device should close the `Modify` RPC upon receiving the first `ModifyRequest` message, and the device should set the generic gRPC [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) to `UNIMPLEMENTED`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `UNSUPPORTED_PARAMS`. The following are the default parameters:
* `redundancy` = `ALL_PRIMARY`.
* `persistence` = `DELETE`
* `ack_type` = `RIB_ACK`

### 4.1.2 Election ID

The election ID informs the device of the result of an external election amongst the clients connected to it (redundancy mode is defined in x.y.z).

Election ID should only be used in `SINGLE_PRIMARY` mode. If the agreed redundancy mode is `ALL_PRIMARY`, but a client populates either `ModifyRequest.election_id` or `AFTOperation.election_id`, the device should close the `Modify` RPC and set `Status.code` to `FAILED_PRECONDITION`. The `Status.details` should contain `ModifyRPCErrorDetails` message with `reason` set to `ELECTION_ID_IN_ALL_PRIMARY`.

There are two fields for election ID.
* `ModifyRequest.election_id` is to indicate the clients election result. It should only be populated when the client's election ID changed after an election result (election is defined in x.y.z).
* `AFTOperation.election_id` is consumed by the server to determine whether to process the AFTOperation. In `SINGLE_PRIMARY` mode, an `AFTOperation` message should always have the `election_id` populated.

In `SINGLE_PRIMARY` mode, the device processes the `AFTOperation` only if all the following conditions met:
* The `AFTOperation.election_id` is equal to the `ModifyRequest.election_id` last advertised by the client.
* The `AFTOperation.election_id` has the highest value amongst all the election IDs that the device knows about, i.e., the client is the primary client.

Otherwise, the device discards the `AFTOperation` and returns a `ModifyResponse` with `AFTResult` = `FAILED`.

`ModifyRequest.election_id` MUST be non zero. When a device receives an value of 0, it should close the `Modify` RPC and set `Status.code` to `INVALID_ARGUMENT`. The election ID can only be increased monotonically by a client during a RPC session. This simplifies server implementation.

#### 4.1.2.1 Election ID Reset

There is no motivation to provide any way for clients to reset the election ID on the device since it is expected to be determined through a stable election mechanism. In the scenario that a client were to lose track of the highest election ID known by the device, the value can be learned via the `ModifyResponse.election_id` from the device, by sending a `ModifyRequest` with `ModifyRequest.election_id` set to the lowest possible value (1) (see x.y.z for more details).

It is possible that in some scenarios (e.g., daemon crash, device reboot) the device might lose the highest learned election ID and hence unset it. However, a device SHOULD NOT reset the value in any cases (e.g., all clients disconnect). This helps reduce the chance of non-primary client programming the device in some failure scenarios (e.g., some error happens on clients side that might lead to split-brain among clients and also cause all clients disconnect and then reconnect).

### 4.1.3 AFTOperation

A client expresses modifications to the RIB modification by sending a set of `AFTOperation` messages. Three types of operations are supported:
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

Device executes the received AFTOperations and streams the results to the sender (a gRIBI client) via a list of `AFTResult` messages in `ModifyResponse`.
* Each AFTOperation should be responded individually. The device MUST NOT stream the results to clients other than the sender (see x.y.z for client definition).
* The device SHOULD NOT close the RPC session due to errors encountered processing an AFTOperation. The errors should be responded to with in-band error messages within the stream (see `AFTResult` below).

An `AFTResult` message must have the followings fields populated by the device:
* `id` - indicates which AFTOperation this message is about.  It corresponds to the `id` field of the received `AFTOperation` message.
* `status` - records the execution result of the AFTOperation. It can have one of the following values. Note, not all `status` values are available in every acknowlege mode (x.y.z defines acknowledge mode).
  * `FAILED` - indicates that the AFTOperation can not be programmed into the RIB (e.g. missing reference, invalid content, semantic errors, etc).
    * Available in all acknowledge modes.
  * `RIB_PROGRAMMED` - indicates that the AFTOperation was successfully programmed into the RIB.
    * Available in all acknowledge modes.
    * OPTIONAL in the case of `FIB_PROGRAMMED`.
  * `FIB_PROGRAMMED` - indicates that the AFTOperation was successfully programmed into the FIB. "Programmed into the FIB" is defined as the forwarding entry being operational in the underlying forwarding resources across the system that it is relevant to (e.g., all linecards that host a particular VRF etc).
    * Only available in the `RIB_AND_FIB_ACK` acknowledge mode.
    * Implies that the AFTOperation was also successfully programmed into the RIB.
  * `FIB_FAILED` - indicates that the AFTOperation was meant to be programmed into the FIB. However, the device failed to program the AFTOperation into the FIB.
* `timestamp` - records the time at which the gRIBI daemon received and processed the result from the underlying systems in the device. The typical use for this timestamp is to provide tracking of programming SLIs.

In `RIB_AND_FIB_ACK` acknowledge mode, it's possible that a gRIBI entry is installed in the RIB, but is not the preferred route (e.g., there is a static route for the same matching entry), and therefore the gRIBI entry will not be programmed into the FIB. In this case, the device should only respond with the `status` value `RIB_PROGRAMMED`.

##### [TODO] 4.1.3.3.1 Idemopotent ADD and REPLACE

Clarify the following scenarios:
* An entry is already installed in the FIB, received an AFTOperation for adding the same entry.
* An entry was failed to be programmed into the FIB, received an AFTOperation for adding the same entry.

##### 4.1.3.3.2 Coalesced AFTOperations

In some scenarios, a device might coalesce multiple AFTOperations on a given gRIBI entry and only execute the last one. This would be primarily done for performance optimization.

In this case, as long as the session is still up and the client is still the primary client, the device SHOULD ACK/NACK (defined in x.y.z) each individual AFTOperation from the same primary client.

This is required in order to:
* Keep the API behavior clear and consistent.
* Allow the sender (client) to avoid tracking the content of the pending AFTOperations.

The server (device) has context of all pending `AFTOperation` messages, since it must potentially ACK any individual operation. Sending an ACK/NACK per message does not present a significant cost.
The requirement to send ACK/NACK for coalesced (skipped) AFTOperations does raise the question as to whether the entry was ever in the RIB or FIB. This is not currently considered as a core requirement - since the expectation is clients care about the latest state of either table. If future use cases/issues require such insight, we can introduce additional fields to indicate that the operation was coalesced (i.e., was never actually programmed in the FIB) in the response, such that the current ACK/NACK semantics are not overloaded.

#### 4.1.3.4 Life cycle of an `AFTOperation`

The life of an AFTOperation starts when a client creates it, and ends in the following scenarios:
* The device failed to program the operation into RIB. // Return `FAILED`.
* `ack_type` = `RIB_ACK`, the device programmed the operation into RIB successfully. // Return `RIB_PROGRAMMED`.
* `ack_type` = `RIB_AND_FIB_ACK`, the device programmed the operation into FIB successfully. // Return `FIB_PROGRAMMED`.
* `ack_type` = `RIB_AND_FIB_ACK`, the device has successfully programmed the operation into RIB but failed to program it into FIB. // Return `FIB_FAILED`. Note that this is regardless if a device is going to retry the FIB programming or not. The client can promptly send another `AFTOperations` for explicit behaviors (e.g. `ADD` for retry, and `DELETE` for stopping retry).
* The existing gRPC session is disconnected/canceled. All pending `AFTOperations` from the client should be cancelled.
* The device has discovered a change in the elected leader (see x.y.z for more details).

Only during the life cycle should the device keep the client updated via `AFTResult` message. 

### 4.1.4 Redundancy Mode

`Modify` can operate in one of the following redundancy mode:
* `SINGLE_PRIMARY`: The device accepts `AFTOperations` from the primary client only. The device discards `AFTOperations` received from non-primary client and responses error (see x.y.x for details). 
* `ALL_PRIMARY`: The device accepts AFTOperations from all clients. [Place holder for more details]

#### 4.1.4.1 Client Election In `SINGLE_PRIMARY`

gRIBI server does not paticipate in the election process, rather it consumes the election result. Election result is reflected in the `ModifyRequest.election_id` sent by clients. gRIBI server treats the client of the highest election ID as the primary client.

When a client's election ID changed, the client should send a `ModifyRequest` with only the `ModifyRequest.election_id` populated. The device should respond with a `ModifyResponse` that has only the `election_id` field populated. The `ModifyResponse.election_id` by the server should be the highest election ID that the device has learnt from any client.

If the `ModifyRequest.election_id` sent by a client matches the previous highest value, the newer client is considered primary. This allows for a client to reconnect
without an external election having taken place. It is gRIBI clients' responsibility to avoid more than one `Modify` RPC sessions that are of the same highest Election ID, i.e., "dual-primary" situation in a `SINGLE_PRIMARY` mode.

#### 4.1.4.2 New Leader Election In `SINGLE_PRIMARY`
Switching to a new leader client occurs when a new client connects with `ModifyRequest.election_id` equals to, or greater than, the previous highest value that learnt by the server from any client.

Upon discovering a new leader has been elected, the device:
* SHOULD stop processing pending `AFTOperations` that were sent by the previous primary.
* MUST not send responses for `AFTOperations` of the previous primary to the acquiring-primary.

### 4.1.6 Persistence modes

Persistence mode specifies if the device should tie the validity of the received gRIBI entries from a client to the livelenss of the `Modify` RPC session. [x.y.z client-server session negotiation]() defines how the persistence mode is agreed between client and server.

`Modify` can operate in one of the following modes. The definition of "disconnects" in this section includes timeout and cancelation of the `Modify` RPC session.
* `DELETE` - When a client disconnects, the device should deletes all gRIBI entries, received from that client, in RIB and FIB.
  * [TODO] might need to clarify some behaviors in `ALL_PRIMARY` mode.
* `PRESERVE` - A client's disconnection SHOULD NOT trigger the device to delete any gRIBI entry, received from that client, in RIB or FIB.

No matter which mode the `Modify` RPC session is operating in, it is always the new primary client's (in case of [`SINGLE_PRIMARY`](x.y.z)) or other clients' (in case of [`ALL_PRIMARY`](x.y.z)) responsibility to do the reconciliation (e.g. via [`Get`](x.y.z) and [`Modify`](x.y.z) RPC).

### 4.1.9 About gRIBI Server Caching
gRIBI server implementation is not required to cache all installed objects.
Implications:
  * When a VRF is removed (e.g. accidentally by user via cli):
    * The device is not required to maintain gRIBI objects in the FIB or RIB.
    * Get() or Flush() should return failed (because the VRF is no longer there)
    * When the VRF is added back, the server is not required to restore all the gRIBI objects by itself.

### 4.1.10 Acknowledge Mode

Acknowledge mode indicates how much details should the device update the client on the result of executing the received `AFTOperations`. [x.y.z client-server session negotiation]() defines how the mode is agreed between client and server.

`Modify` can operate in one of the following acknowledge modes.
* `RIB_ACK`: Afer sending an `AFTOperation`, the client expects the device to respond whether if the `AFTOperation` has been successfully programmed in the RIB.
* `RIB_AND_FIB_ACK`: Afer sending an `AFTOperation`, the client expects the device to respond whether if the `AFTOperation` has been successfully programmed in both RIB and FIB.

The response is reflected in `AFTResult.status` (see [x.y.z AFTOperation response](a_link)).

### 4.1.11 gRIBI Route Preference

A device might learn routing information of the same destination from different protocols (e.g., static route, gRIBI, OSPF, BGP, etc.). In that case, the device by default should prefer gRIBI over other distributed routing protocols (e.g., OSPF, BGP, etc.), and should prefer static route over gRIBI.

The preference is often indicated by different values (often known as Administrative Distance or Route Preference) in a network device OS. The values are locally significant to different device OS. This spec does not enforce the exact value that a device OS should assign to gRIBI protocol.

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

## 4.3 `Flush`

The `Flush` RPC is an unary RPC for clients to remove gRIBI entries from a device. A client sends a `FlushRequest` message specifying the target network instance where the device should remove all gRIBI entries. The device processes the request and responds a `FlushResponse` message indicating the execution result.

The `Flush` RPC can be used in some emergency process to get the device out of undesirable routing state, therefore:
* This RPC provides a low complexity method to remove all gRIBI entries in specified network instance.
* This RPC allows non primary client (in `SINGLE_PRIMARY` mode) to remove all gRIBI entries in specified network instance.

### 4.3.1 `FlushRequest` Message

A `FlushRequest` message MUST have the `network_instance` populated by client.
* If `network_instance` is nil or `network_instance.name` is en empty string, the device should reject the request with gRPC error [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `INVALID_ARGUMENT`. The `Status.details` should contain `FlushResponseError` message with `reason` set to `INVALID_NETWORK_INSTANCE`.
* If the specified network instance does not exist, the device should reject the request with gRPC error [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `INVALID_ARGUMENT`. The `Status.details` should contain `FlushResponseError` message with `reason` set to `NO_SUCH_NETWORK_INSTANCE`.

#### 4.3.1.1 `election` In `FlushRequest` Message

Only when the client-server is in `SINGLE_PRIMARY` mode (defined in x.y.z) MUST the `election` be populated by the client.
* If the `election` is set when the client-server is in `ALL_PRIMARY` mode (defined in x.y.z), the request should be rejected by the device with gRPC error [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `FAILED_PRECONDITION`. The `Status.details` should contain `FlushResponseError` message with `reason` set to `ELECTION_ID_IN_ALL_PRIMARY`.
* If the `election` is not set when the client-server is in `SINGLE_PRIMARY` mode (defined in x.y.z), the request should be rejected by the device with gRPC error [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `FAILED_PRECONDITION`. The `Status.details` should contain `FlushResponseError` message with `reason` set to `UNSPECIFIED_ELECTION_BEHAVIOR`.

When the client-server is in `SINGLE_PRIMARY` mode:
* If `election` is `id`, the server should process the flush request only if the request is from the primary client.
  * If the `id` value is equal or greater to the previous highest device known `election_id` (see x.y.z), the flush request should be accepted by the device.
  * if the `id` value is less than the previous highest device known `election_id` (see x.y.z), the flush request should be rejected by the device with gRPC error [`Status.code`](https://github.com/googleapis/googleapis/blob/master/google/rpc/status.proto) set to `FAILED_PRECONDITION`. The `Status.details` should contain `FlushResponseError` message with `reason` set to `NOT_PRIMARY`.
* If `election` is `override`, the flush request should be accepted by the device regardless if the client is the primary.

### 4.3.2 `FlushResponse` message

The `timestamp` is when the flush operation completed on the device. It is set by the device in nanoseconds since the Unix epoch.

If the device has removed all gRIBI entries in the client specified network instance, the device should set `FlushResponse.result` to `OK`.

It is possible that the client targeted network instance contains Next Hops or Next Hop Groups that are referenced by other network instances not specified by the client. We call those Next Hops and Next Hop Groups non-zero-referenced. The device SHOULD keep the non-zero-referenced, but remove all other gRIBI entries in the specified network instance. In this case, the device should set `FlushResponse.result` to `NON_ZERO_REFERENCE_REMAIN`.

### 4.3.3 Error Handling

Error encountered by the device removing a gRIBI entry SHOULD NOT block the device from continuing the effort removing other gRIBI entries, unless the error is a fatal error (e.g. daemon/job crash).

If any error encountered during the operation, the device should return gRPC error with `Status.code` set to `INTERNAL`.