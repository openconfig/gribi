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

package gRIBIServer

import (
	"context"
	"fmt"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"

	log "github.com/golang/glog"
	"github.com/golang/protobuf/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"

	rpb "gob/gribi/proto/service"

	gpb "github.com/openconfig/gnmi/proto/gnmi"
)

// Check that Server implements both the gNMI and gRIBI server interfaces.
var _ gpb.GNMIServer = (*Server)(nil)
var _ rpb.GRIBIServer = (*Server)(nil)

// newServer creates a test gNMI + gRIBI test server that can be used to
// validate request/responses within tests. It returns a pointer to the created
// gRPC server, a pointer to the listener created, and the (dynamically allocated)
// TCP port that the server is listening on.
func newServer(s *Server) (*grpc.Server, net.Listener, uint16, error) {
	listener, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		return nil, nil, 0, err
	}

	gs := grpc.NewServer()
	log.Infof("Created test server on %s", listener.Addr().String())

	ap := strings.Split(listener.Addr().String(), ":")
	tcpPort, err := strconv.ParseUint(ap[len(ap)-1], 10, 16)
	if err != nil {
		return nil, nil, 0, err
	}

	gpb.RegisterGNMIServer(gs, s)
	reflection.Register(gs)
	rpb.RegisterGRIBIServer(gs, s)
	log.Infof("Registered test servers")

	return gs, listener, uint16(tcpPort), nil
}

func newClients(tcpPort uint16, opts ...grpc.DialOption) (gpb.GNMIClient, rpb.GRIBIClient, func(), error) {
	log.Infof("Connecting clients to localhost:%d", tcpPort)
	conn, err := grpc.Dial(fmt.Sprintf("localhost:%d", tcpPort), opts...)
	if err != nil {
		return nil, nil, nil, err
	}
	log.Infof("Client connected")
	return gpb.NewGNMIClient(conn), rpb.NewGRIBIClient(conn), func() { conn.Close() }, nil
}

func TestUnimplementedGNMIMethods(t *testing.T) {
	s := &Server{}
	gs, listener, port, err := newServer(s)
	if err != nil {
		t.Fatalf("TestUnimplementedMethods: cannot create server: %v", err)
	}
	go gs.Serve(listener)
	defer gs.Stop()

	gnmiC, gribiC, cleanup, err := newClients(port, grpc.WithInsecure())
	if err != nil {
		t.Fatalf("TestUnimplementedMethods: cannot create clients: %v", err)
	}
	defer cleanup()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, geterr := gnmiC.Get(ctx, &gpb.GetRequest{})
	_, seterr := gnmiC.Set(ctx, &gpb.SetRequest{})
	_, caperr := gnmiC.Capabilities(ctx, &gpb.CapabilityRequest{})

	// Subscribe is a bidir streaming RPC so we must call Recv on the client.
	sc, err := gnmiC.Subscribe(ctx)
	if err != nil {
		t.Errorf("gnmi.Subscribe(): Received error when creating client: %v", err)
	}
	_, suberr := sc.Recv()

	// Modify is a bidir streaming RPC so we must call Recv on the client.
	rc, err := gribiC.Modify(ctx)
	if err != nil {
		t.Errorf("gribi.Modify(): Received error when creating client: %v", err)
	}
	_, moderr := rc.Recv()

	tests := []struct {
		name     string
		gotErr   error
		wantCode codes.Code
		wantMsg  string
	}{{
		name:     "gNMI Get",
		gotErr:   geterr,
		wantCode: codes.Unimplemented,
		wantMsg:  "Get RPC is unimplemented for the gRIBI fake",
	}, {
		name:     "gNMI Set",
		gotErr:   seterr,
		wantCode: codes.Unimplemented,
		wantMsg:  "Set RPC is unimplemented for the gRIBI fake",
	}, {
		name:     "gNMI Capabilities",
		gotErr:   caperr,
		wantCode: codes.Unimplemented,
		wantMsg:  "Capabilities RPC is unimplemented for the gRIBI fake",
	}, {
		name:     "gNMI Subscribe",
		gotErr:   suberr,
		wantCode: codes.Unimplemented,
		wantMsg:  "TODO",
	}, {
		name:     "gRIBI Modify",
		gotErr:   moderr,
		wantCode: codes.Unimplemented,
		wantMsg:  "TODO",
	}}

	for _, tt := range tests {
		want := status.New(tt.wantCode, tt.wantMsg)
		if got, perr := status.FromError(tt.gotErr); !perr {
			t.Errorf("TestUnimplementedMethods: %s: could not convert returned error to status: %v", tt.name, perr)
		} else {
			if gp, wp := got.Proto(), want.Proto(); !proto.Equal(got.Proto(), want.Proto()) {
				t.Errorf("TestUnimplementedMethods: %s(): did not get expected error, got: %v, want: %s", tt.name, proto.MarshalTextString(gp), proto.MarshalTextString(wp))
			}
		}
	}
}
