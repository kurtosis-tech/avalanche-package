package main

import (
	"context"
	"fmt"
	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/constants"
	"github.com/ava-labs/avalanchego/vms/avm"
	"github.com/ava-labs/avalanchego/vms/platformvm"
	"github.com/ava-labs/avalanchego/vms/platformvm/txs"
	"github.com/ava-labs/avalanchego/vms/secp256k1fx"
	"github.com/ava-labs/avalanchego/wallet/chain/p"
	"github.com/ava-labs/avalanchego/wallet/chain/x"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary/common"
	"os"
	"time"
)

const (
	uriIndex        = 1
	taskArg = 2
	minArgs         = 3
	nonZeroExitCode = 1
)

type wallet struct {
	addr     ids.ShortID
	pWallet  p.Wallet
	pBackend p.Backend
	pBuilder p.Builder
	pSigner  p.Signer
	xWallet  x.Wallet
}

var (
	defaultPoll = common.WithPollFrequency(100 * time.Millisecond)
)

func main() {
	if len(os.Args) < minArgs {
		fmt.Printf("Need at least '%v' args got '%v'\n",, minArgs, len(os.Args))
		os.Exit(nonZeroExitCode)
	}

	uri := os.Args[uriIndex]
	w, err := newWallet(uri)
	if err != nil {
		fmt.Printf("Couldn't create wallet \n")
		os.Exit(nonZeroExitCode)
	}
	
	task := os.Args[taskArg]
	switch task {
	case "CreateSubnet":
		subnetId, err := createSubnet(w)
		if err != nil {
			fmt.Printf("an error occurred while creating subnet: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("subnet created with id '%v' \n", subnetId)
	}

}

func createSubnet(w * wallet) (ids.ID, error) {
	ctx := context.Background()
	subnetId, err := w.pWallet.IssueCreateSubnetTx(
		&secp256k1fx.OutputOwners{
			Threshold: 1,
			Addrs:     []ids.ShortID{w.addr},
		},
		common.WithContext(ctx),
		defaultPoll,
	)
	if err != nil {
		return ids.Empty, err
	}

	return subnetId, err
}

func newWallet(uri string) (*wallet, error) {
	ctx := context.Background()
	kc := secp256k1fx.NewKeychain(genesis.EWOQKey)
	pCTX, xCTX, utxos, err := primary.FetchState(ctx, uri, kc.Addresses())
	if err != nil {
		return nil, err
	}
	// platform client
	pClient := platformvm.NewClient(uri)
	// TODO verify previous transactions - can be empty
	pTXs := make(map[ids.ID]*txs.Tx)
	// TODO perhaps this chain ID should be 43112 and not empty
	pUTXOs := primary.NewChainUTXOs(constants.PlatformChainID, utxos)
	xChainID := xCTX.BlockchainID()
	xUTXOs := primary.NewChainUTXOs(xChainID, utxos)
	var w wallet
	w.addr = genesis.EWOQKey.PublicKey().Address()
	w.pBackend = p.NewBackend(pCTX, pUTXOs, pTXs)
	w.pBuilder = p.NewBuilder(kc.Addresses(), w.pBackend)
	w.pSigner = p.NewSigner(kc, w.pBackend)
	w.pWallet = p.NewWallet(w.pBuilder, w.pSigner, pClient, w.pBackend)

	xBackend := x.NewBackend(xCTX, xChainID, xUTXOs)
	xBuilder := x.NewBuilder(kc.Addresses(), xBackend)
	xSigner := x.NewSigner(kc, xBackend)
	xClient := avm.NewClient(uri, "X")
	w.xWallet = x.NewWallet(xBuilder, xSigner, xClient, xBackend)
	return &w, nil

}
