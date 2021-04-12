// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package gRIBIServer is an implementation of the gRIBI gRPC RIB programming interface.
// It interacts with a fake backend which is stored using ygot generated structs.
package gRIBIServer

import (
	"context"
	"sync"

	"github.com/openconfig/gribi/oc"

	"github.com/openconfig/ygot/ygot"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	rpb "github.com/openconfig/gribi/proto/service"

	gpb "github.com/openconfig/gnmi/proto/gnmi"
)

// Server acts as a fake gRIBI server. It can be used to test a gRIBI client
// implementation against, and serves as a reference implementation describing
// the behaviour that is expected of a gRIBI server.
//
// It implements both the gRIBI service, and the gNMI service. When a modifications
// to the RIB is written, it is stored in a per-client instance of the AFT model.
// A decision process is applied based on the clients that exist, and the
// "best" entry is then stored in the overall AFT for the device. When modifications
// to the selected AFT entries are made, these are transmitted as gNMI notifications.
type Server struct {
	// aft stores the backend implementation's selected set of AFT entries.
	aft *internalAFT
	// changes is a channel which is written to by the server when changes occur
	// within the AFT. This allows event-based subscriptions to be supplied with
	// the changes to the AFT entry. The channel passes pointers to a ygot.GoStruct
	// which can be serialised to the relevant format by the RPC handler.
	changes chan *ygot.GoStruct
	// clientAFT stores the backend implementat's per-client AFT entries. It is
	// keyed by a per-client identifier which may be derived from the client address
	// or explicitly specified by the client.
	// TODO(robjs): Clarify how the explicit specification by the client works.
	clientAFT map[string]*internalAFT
}

// internalAFT is an internally stored abstract forwarding table (AFT), which is
// associated with a particular context within the fake gRIBI server.
type internalAFT struct {
	// mu is a read-write mutex that protects accesses to the AFT stored by the internal AFT.
	mu sync.RWMutex
	// aft is the contents of the AFT.
	aft *oc.GribiAft_Afts
}

// Modify is a bidirectional streaming RPC handler which provides a mechanism to
// modify the RIB entries on a device via the gRIBI gRPC service.
func (*Server) Modify(rpb.GRIBI_ModifyServer) error {
	return status.Errorf(codes.Unimplemented, "TODO")
}

// Capabilities ensures that Server implements the gNMI server interface. It is
// unimplemented in this fake.
func (*Server) Capabilities(_ context.Context, _ *gpb.CapabilityRequest) (*gpb.CapabilityResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "Capabilities RPC is unimplemented for the gRIBI fake")
}

// Get ensures that Server implements the gNMI server interface. It is unimplemented
// in this fake.
func (*Server) Get(_ context.Context, _ *gpb.GetRequest) (*gpb.GetResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "Get RPC is unimplemented for the gRIBI fake")
}

// Set ensures that the Server implements the gNMI server interface. It is unimplemented
// in this fake.
func (*Server) Set(_ context.Context, _ *gpb.SetRequest) (*gpb.SetResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "Set RPC is unimplemented for the gRIBI fake")
}

// Subscribe implements the gNMI subscribe RPC. It can be used by a gRIBI client to
// determine whether an entry that was injected into the system was written to the
// active AFT of the system - through creating a subscription to the AFTs on the system.
// Alternatively, a client may retrieve the entire set of active AFT entries through
// use of the Subscribe ONCE mode, whereby a complete set of the referenced path is
// serialised and sent to the client.
func (s *Server) Subscribe(gpb.GNMI_SubscribeServer) error {
	return status.Errorf(codes.Unimplemented, "TODO")
}
