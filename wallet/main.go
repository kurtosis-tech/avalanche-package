package main

import (
	"context"
	"fmt"
	"github.com/ava-labs/avalanche-network-runner/utils"
	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/constants"
	"github.com/ava-labs/avalanchego/utils/perms"
	"github.com/ava-labs/avalanchego/vms/avm"
	"github.com/ava-labs/avalanchego/vms/components/avax"
	"github.com/ava-labs/avalanchego/vms/components/verify"
	"github.com/ava-labs/avalanchego/vms/platformvm"
	"github.com/ava-labs/avalanchego/vms/platformvm/txs"
	"github.com/ava-labs/avalanchego/vms/secp256k1fx"
	"github.com/ava-labs/avalanchego/wallet/chain/p"
	"github.com/ava-labs/avalanchego/wallet/chain/x"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary/common"
	"os"
	"strconv"
	"time"
)

const (
	uriIndex               = 1
	vmNameIndex            = 2
	chainNameIndex         = 3
	numValidatorNodesIndex = 4
	isElasticIndex         = 5
	minArgs                = 6
	nonZeroExitCode        = 1
	nodeIdPathFormat       = "/tmp/data/node-%d/node_id.txt"

	// validate from a minute after now
	startTimeDelayFromNow = 1 * time.Minute
	// validate for 14 days
	endTimeFromStartTime = 14 * 24 * time.Hour
	// random stake weight of 200
	stakeWeight = uint64(200)

	// outputs
	parentPath         = "/tmp/subnet/node-%d"
	chainIdOutput      = "/tmp/subnet/chainId.txt"
	vmIdOutput         = "/tmp/subnet/vmId.txt"
	subnetIdOutput     = "/tmp/subnet/subnetId.txt"
	validatorIdsOutput = "/tmp/subnet/node-%d/validator_id.txt"
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
		fmt.Printf("Need at least '%v' args got '%v'\n", minArgs, len(os.Args))
		os.Exit(nonZeroExitCode)
	}

	uri := os.Args[uriIndex]
	vmName := os.Args[vmNameIndex]
	chainName := os.Args[chainNameIndex]
	numValidatorNodesArg := os.Args[numValidatorNodesIndex]
	numValidatorNodes, err := strconv.Atoi(numValidatorNodesArg)
	if err != nil {
		fmt.Printf("An error occurred while converting numValidatorNodes arg to integer: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
	isElasticArg := os.Args[isElasticIndex]
	isElastic, err := strconv.ParseBool(isElasticArg)
	if err != nil {
		fmt.Printf("an error occurred converting is elastic '%v' to bool", isElastic)
	}

	fmt.Printf("trying uri '%v' vmName '%v' chainName '%v' and numValidatorNodes '%v'", uri, vmName, chainName, numValidatorNodes)

	w, err := newWallet(uri)
	if err != nil {
		fmt.Printf("Couldn't create wallet \n")
		os.Exit(nonZeroExitCode)
	}

	subnetId, err := createSubnet(w)
	if err != nil {
		fmt.Printf("an error occurred while creating subnet: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
	fmt.Printf("subnet created created with id '%v'\n", subnetId)

	vmID, err := utils.VMID(vmName)
	if err != nil {
		fmt.Printf("an error occurred while creating vmid for vmname '%v'", vmName)
		os.Exit(nonZeroExitCode)
	}

	chainId, err := createBlockChain(w, subnetId, vmID, chainName)
	if err != nil {
		fmt.Printf("an erorr occurred while creating chain: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
	fmt.Printf("chain created with id '%v' and vm id '%v'\n", chainId, vmID)

	validatorIds, err := addSubnetValidators(w, subnetId, numValidatorNodes)
	if err != nil {
		fmt.Printf("an error occurred while adding validators: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
	fmt.Printf("validators added with ids '%v'\n", validatorIds)

	err = writeOutputs(subnetId, vmID, chainId, validatorIds)
	if err != nil {
		fmt.Printf("an error occurred while writing outputs: %v\n", err)
		os.Exit(nonZeroExitCode)
	}

	if isElastic {
		assetId, exportId, importId, err := createAssetOnXChainImportToPChain(w, "foo token", "FOO", 9, 100000)
		if err != nil {
			fmt.Printf("an error occurred while creating asset: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("created asset '%v' exported with id '%v' and imported with id '%v'\n", assetId, exportId, importId)
	}
}

func writeOutputs(subnetId ids.ID, vmId ids.ID, chainId ids.ID, validatorIds []ids.ID) error {
	for index, validatorId := range validatorIds {
		if err := os.MkdirAll(fmt.Sprintf(parentPath, index), 0700); err != nil {
			return err
		}
		err := os.WriteFile(fmt.Sprintf(validatorIdsOutput, index), []byte(validatorId.String()), perms.ReadOnly)
		if err != nil {
			return err
		}
	}
	if err := os.WriteFile(chainIdOutput, []byte(chainId.String()), perms.ReadOnly); err != nil {
		return err
	}
	if err := os.WriteFile(subnetIdOutput, []byte(subnetId.String()), perms.ReadOnly); err != nil {
		return err
	}
	if err := os.WriteFile(vmIdOutput, []byte(vmId.String()), perms.ReadOnly); err != nil {
		return err
	}
	return nil
}

func createAssetOnXChainImportToPChain(w *wallet, name string, symbol string, denomination byte, maxSupply uint64) (ids.ID, ids.ID, ids.ID, error) {
	ctx := context.Background()
	owner := &secp256k1fx.OutputOwners{
		Threshold: 1,
		Addrs: []ids.ShortID{
			genesis.EWOQKey.PublicKey().Address(),
		},
	}
	assetId, err := w.xWallet.IssueCreateAssetTx(
		name,
		symbol,
		denomination,
		// borrowed from https://github.com/ava-labs/avalanche-cli/blob/917ef2e440880d68452080b4051c3031be76b8af/pkg/subnet/local.go#L101C32-L111
		map[uint32][]verify.State{
			0: {
				&secp256k1fx.TransferOutput{
					Amt:          maxSupply,
					OutputOwners: *owner,
				},
			},
		},
		common.WithContext(ctx),
	)
	if err != nil {
		return ids.Empty, ids.Empty, ids.Empty, fmt.Errorf("an error occurred while creating asset: %v", err)
	}
	exportId, err := w.xWallet.IssueExportTx(
		ids.Empty,
		[]*avax.TransferableOutput{
			{
				Asset: avax.Asset{
					ID: assetId,
				},
				Out: &secp256k1fx.TransferOutput{
					Amt:          maxSupply,
					OutputOwners: *owner,
				},
			},
		},
		common.WithContext(ctx),
	)
	if err != nil {
		return ids.Empty, ids.Empty, ids.Empty, fmt.Errorf("an error occurred while issuing asset export: %v", err)
	}
	importId, err := w.pWallet.IssueImportTx(
		w.xWallet.BlockchainID(),
		owner,
		common.WithContext(ctx),
	)
	if err != nil {
		return ids.Empty, ids.Empty, ids.Empty, fmt.Errorf("an error occurred while issuing asset import: %v", err)
	}
	return assetId, exportId, importId, nil
}

func addSubnetValidators(w *wallet, subnetId ids.ID, numValidators int) ([]ids.ID, error) {
	var validatorIDs []ids.ID
	startTime := time.Now().Add(startTimeDelayFromNow)
	endTime := startTime.Add(endTimeFromStartTime)
	for index := 0; index < numValidators; index++ {
		nodeIdPath := fmt.Sprintf(nodeIdPathFormat, index)
		nodeIdBytes, err := os.ReadFile(nodeIdPath)
		if err != nil {
			return nil, fmt.Errorf("an error occurred while reading node id '%v': %v", nodeIdPath, err)
		}
		nodeId, err := ids.NodeIDFromString(string(nodeIdBytes))
		if err != nil {
			return nil, fmt.Errorf("couldn't convert '%v' to node id", string(nodeIdBytes))
		}
		validatorId, err := w.pWallet.IssueAddSubnetValidatorTx(
			&txs.SubnetValidator{
				Validator: txs.Validator{
					NodeID: nodeId,
					Start:  uint64(startTime.Unix()),
					End:    uint64(endTime.Unix()),
					Wght:   stakeWeight,
				},
				Subnet: subnetId,
			},
		)
		if err != nil {
			return nil, fmt.Errorf("an error occurred while adding node '%v' as validator: %v", index, err)
		}
		validatorIDs = append(validatorIDs, validatorId)
	}

	return validatorIDs, nil
}

func createBlockChain(w *wallet, subnetId ids.ID, vmId ids.ID, chainName string) (ids.ID, error) {
	ctx := context.Background()
	genesisData, err := os.ReadFile("/tmp/wallet/genesis.json")
	if err != nil {
		return ids.Empty, err
	}
	var nilFxIds []ids.ID
	chainId, err := w.pWallet.IssueCreateChainTx(
		subnetId,
		genesisData,
		vmId,
		nilFxIds,
		chainName,
		common.WithContext(ctx),
		defaultPoll,
	)
	if err != nil {
		return ids.Empty, nil
	}
	return chainId, nil
}

func createSubnet(w *wallet) (ids.ID, error) {
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

	return subnetId, nil
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
	pTXs := make(map[ids.ID]*txs.Tx)
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
