package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/ava-labs/avalanchego/wallet/chain/c"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/perms"
	"github.com/ava-labs/avalanchego/vms/components/avax"
	"github.com/ava-labs/avalanchego/vms/components/verify"
	"github.com/ava-labs/avalanchego/vms/platformvm/reward"
	"github.com/ava-labs/avalanchego/vms/platformvm/signer"
	"github.com/ava-labs/avalanchego/vms/platformvm/txs"
	"github.com/ava-labs/avalanchego/vms/secp256k1fx"
	"github.com/ava-labs/avalanchego/wallet/chain/p"
	"github.com/ava-labs/avalanchego/wallet/chain/x"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary"
	"github.com/ava-labs/avalanchego/wallet/subnet/primary/common"
)

const (
	uriIndex               = 1
	vmIDArgIndex           = 2
	chainNameIndex         = 3
	numValidatorNodesIndex = 4
	isElasticIndex         = 5
	minArgs                = 6
	nonZeroExitCode        = 1
	nodeIdPathFormat       = "/tmp/data/node-%d/node_id.txt"

	// validate from a minute after now
	startTimeDelayFromNow = 10 * time.Minute
	// validate for 14 days
	endTimeFromStartTime = 28 * 24 * time.Hour
	// random stake weight of 200
	stakeWeight = uint64(200)

	// outputs
	parentPath           = "/tmp/subnet/node-%d"
	chainIdOutput        = "/tmp/subnet/chainId.txt"
	subnetIdOutput       = "/tmp/subnet/subnetId.txt"
	validatorIdsOutput   = "/tmp/subnet/node-%d/validator_id.txt"
	allocationsOutput    = "/tmp/subnet/allocations.txt"
	genesisChainIdOutput = "/tmp/subnet/genesisChainId.txt"

	// permissionless
	assetIdOutput          = "/tmp/subnet/assetId.txt"
	exportIdOutput         = "/tmp/subnet/exportId.txt"
	importIdOutput         = "/tmp/subnet/importId.txt"
	transformationIdOutput = "/tmp/subnet/transformationId.txt"

	// delimiters
	allocationDelimiter = ","
	addrAllocDelimiter  = "="
)

// https://github.com/ava-labs/avalanche-cli/blob/917ef2e440880d68452080b4051c3031be76b8af/pkg/elasticsubnet/config_prompt.go#L18-L38
const (
	defaultInitialSupply            = 240_000_000
	defaultMaximumSupply            = 720_000_000
	defaultMinConsumptionRate       = 0.1 * reward.PercentDenominator
	defaultMaxConsumptionRate       = 0.12 * reward.PercentDenominator
	defaultMinValidatorStake        = 2_000
	defaultMaxValidatorStake        = 3_000_000
	defaultMinStakeDurationHours    = 14 * 24
	defaultMinStakeDuration         = defaultMinStakeDurationHours * time.Hour
	defaultMaxStakeDurationHours    = 365 * 24
	defaultMaxStakeDuration         = defaultMaxStakeDurationHours * time.Hour
	defaultMinDelegationFee         = 20_000
	defaultMinDelegatorStake        = 25
	defaultMaxValidatorWeightFactor = 5
	defaultUptimeRequirement        = 0.8 * reward.PercentDenominator
)

type wallet struct {
	p p.Wallet
	x x.Wallet
	c c.Wallet
}

type Genesis struct {
	Alloc  map[string]Balance `json:alloc`
	Config Config             `json:config`
}

type Config struct {
	ChainId int `json:chainId`
}

type Balance struct {
	Balance string `json:balance`
}

var (
	defaultPoll = common.WithPollFrequency(500 * time.Millisecond)
)

// It's usage from builder.star is like this
// subnetId, chainId, validatorIds, allocations, genesisChainId, assetId, transformationId, exportId, importId =
// builder_service.create_subnet(plan, first_private_rpc_url, num_validators, is_elastic, vmId, chainName)
func main() {
	if len(os.Args) < minArgs {
		fmt.Printf("Need at least '%v' args got '%v'\n", minArgs, len(os.Args))
		os.Exit(nonZeroExitCode)
	}

	uri := os.Args[uriIndex]
	vmIDStr := os.Args[vmIDArgIndex]
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

	fmt.Printf("trying uri '%v' vmID '%v' chainName '%v' and numValidatorNodes '%v'", uri, vmIDStr, chainName, numValidatorNodes)

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

	vmID, err := ids.FromString(vmIDStr)
	if err != nil {
		fmt.Printf("an error occurred converting '%v' vm id string to ids.ID: %v", vmIDStr, err)
	}
	chainId, allocations, genesisChainId, err := createBlockChain(w, subnetId, vmID, chainName)
	if err != nil {
		fmt.Printf("an erorr occurred while creating chain: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
	fmt.Printf("chain created with id '%v' and vm id '%v'\n", chainId, vmID)

	// disable this for elastic subnet
	var validatorIds []ids.ID
	if !isElastic {
		validatorIds, err = addSubnetValidators(w, subnetId, numValidatorNodes)
		if err != nil {
			fmt.Printf("an error occurred while adding validators: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("validators added with ids '%v'\n", validatorIds)
	}

	var assetId, exportId, importId, transformationId ids.ID
	if isElastic {
		assetId, exportId, importId, err = createAssetOnXChainImportToPChain(w, "foo token", "FOO", 9, 100000000000)
		if err != nil {
			fmt.Printf("an error occurred while creating asset: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("created asset '%v' exported with id '%v' and imported with id '%v'\n", assetId, exportId, importId)
		transformationId, err = transformSubnet(w, subnetId, assetId)
		if err != nil {
			fmt.Printf("an error occurred while transforming subnet: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("transformed subnet and got transformation id '%v'\n", transformationId)
		validatorIds, err = addPermissionlessValidator(w, assetId, subnetId, numValidatorNodes)
		if err != nil {
			fmt.Printf("an error occurred while creating permissionless validators: %v\n", err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("added permissionless validators with ids '%v'\n", validatorIds)
	}

	err = writeOutputs(subnetId, chainId, validatorIds, allocations, genesisChainId, assetId, exportId, importId, transformationId, isElastic)
	if err != nil {
		fmt.Printf("an error occurred while writing outputs: %v\n", err)
		os.Exit(nonZeroExitCode)
	}
}

func writeOutputs(subnetId ids.ID, chainId ids.ID, validatorIds []ids.ID, allocations map[string]string, genesisChainId string, assetId, exportId, importId, transformationId ids.ID, isElastic bool) error {
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
	if err := os.WriteFile(genesisChainIdOutput, []byte(genesisChainId), perms.ReadOnly); err != nil {
		return err
	}
	var allocationList []string
	for addr, balance := range allocations {
		allocationList = append(allocationList, addr+addrAllocDelimiter+balance)
	}
	if err := os.WriteFile(allocationsOutput, []byte(strings.Join(allocationList, allocationDelimiter)), perms.ReadOnly); err != nil {
		return err
	}
	if isElastic {
		if err := os.WriteFile(assetIdOutput, []byte(assetId.String()), perms.ReadOnly); err != nil {
			return err
		}
		if err := os.WriteFile(exportIdOutput, []byte(exportId.String()), perms.ReadOnly); err != nil {
			return err
		}
		if err := os.WriteFile(importIdOutput, []byte(importId.String()), perms.ReadOnly); err != nil {
			return err
		}
		if err := os.WriteFile(transformationIdOutput, []byte(transformationId.String()), perms.ReadOnly); err != nil {
			return err
		}
	}
	return nil
}

func addPermissionlessValidator(w *wallet, assetId ids.ID, subnetId ids.ID, numValidators int) ([]ids.ID, error) {
	ctx := context.Background()
	var validatorIDs []ids.ID
	owner := &secp256k1fx.OutputOwners{
		Threshold: 1,
		Addrs: []ids.ShortID{
			genesis.EWOQKey.PublicKey().Address(),
		},
	}
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
		startTime := time.Now().Add(startTimeDelayFromNow)
		endTime := startTime.Add(endTimeFromStartTime)
		validatorTx, err := w.p.IssueAddPermissionlessValidatorTx(
			&txs.SubnetValidator{
				Validator: txs.Validator{
					NodeID: nodeId,
					Start:  uint64(startTime.Unix()),
					End:    uint64(endTime.Unix()),
					Wght:   6000,
				},
				Subnet: subnetId,
			},
			&signer.Empty{},
			assetId,
			owner,
			&secp256k1fx.OutputOwners{},
			reward.PercentDenominator,
			common.WithContext(ctx),
			defaultPoll,
		)
		if err != nil {
			return nil, fmt.Errorf("an error occurred while adding validator '%v': %v", index, err)
		}
		validatorIDs = append(validatorIDs, validatorTx.ID())
	}
	return validatorIDs, nil
}

func transformSubnet(w *wallet, subnetId ids.ID, assetId ids.ID) (ids.ID, error) {
	ctx := context.Background()
	transformSubnetTx, err := w.p.IssueTransformSubnetTx(
		subnetId,
		assetId,
		uint64(defaultInitialSupply),
		uint64(defaultMaximumSupply),
		uint64(defaultMinConsumptionRate),
		uint64(defaultMaxConsumptionRate),
		uint64(defaultMinValidatorStake),
		uint64(defaultMaxValidatorStake),
		defaultMinStakeDuration,
		defaultMaxStakeDuration,
		uint32(defaultMinDelegationFee),
		uint64(defaultMinDelegatorStake),
		byte(defaultMaxValidatorWeightFactor),
		uint32(defaultUptimeRequirement),
		common.WithContext(ctx),
	)
	if err != nil {
		return ids.Empty, err
	}
	return transformSubnetTx.ID(), err
}

func createAssetOnXChainImportToPChain(w *wallet, name string, symbol string, denomination byte, maxSupply uint64) (ids.ID, ids.ID, ids.ID, error) {
	ctx := context.Background()
	owner := &secp256k1fx.OutputOwners{
		Threshold: 1,
		Addrs: []ids.ShortID{
			genesis.EWOQKey.PublicKey().Address(),
		},
	}
	assetTx, err := w.x.IssueCreateAssetTx(
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
	exportTx, err := w.x.IssueExportTx(
		ids.Empty,
		[]*avax.TransferableOutput{
			{
				Asset: avax.Asset{
					ID: assetTx.ID(),
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
	importTx, err := w.p.IssueImportTx(
		w.x.Builder().Context().BlockchainID,
		owner,
		common.WithContext(ctx),
	)
	if err != nil {
		return ids.Empty, ids.Empty, ids.Empty, fmt.Errorf("an error occurred while issuing asset import: %v", err)
	}
	return assetTx.ID(), exportTx.ID(), importTx.ID(), nil
}

func addSubnetValidators(w *wallet, subnetId ids.ID, numValidators int) ([]ids.ID, error) {
	ctx := context.Background()
	var validatorIDs []ids.ID
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
		startTime := time.Now().Add(startTimeDelayFromNow)
		endTime := startTime.Add(endTimeFromStartTime)
		addValidatorTx, err := w.p.IssueAddSubnetValidatorTx(
			&txs.SubnetValidator{
				Validator: txs.Validator{
					NodeID: nodeId,
					Start:  uint64(startTime.Unix()),
					End:    uint64(endTime.Unix()),
					Wght:   stakeWeight,
				},
				Subnet: subnetId,
			},
			common.WithContext(ctx),
			defaultPoll,
		)
		if err != nil {
			return nil, fmt.Errorf("an error occurred while adding node '%v' as validator: %v", index, err)
		}
		validatorIDs = append(validatorIDs, addValidatorTx.ID())
	}

	return validatorIDs, nil
}

func createBlockChain(w *wallet, subnetId ids.ID, vmId ids.ID, chainName string) (ids.ID, map[string]string, string, error) {
	ctx := context.Background()
	genesisData, err := os.ReadFile("/tmp/subnet-genesis/genesis.json")
	if err != nil {
		return ids.Empty, nil, "", err
	}
	var genesis Genesis
	if err := json.Unmarshal(genesisData, &genesis); err != nil {
		return ids.Empty, nil, "", fmt.Errorf("an error occured while unmarshalling genesis json: %v")
	}
	allocations := map[string]string{}
	for addr, allocation := range genesis.Alloc {
		allocations[addr] = allocation.Balance
	}
	genesisChainId := fmt.Sprintf("%d", genesis.Config.ChainId)
	var nilFxIds []ids.ID
	createChainTx, err := w.p.IssueCreateChainTx(
		subnetId,
		genesisData,
		vmId,
		nilFxIds,
		chainName,
		common.WithContext(ctx),
		defaultPoll,
	)
	if err != nil {
		return ids.Empty, nil, "", nil
	}
	return createChainTx.ID(), allocations, genesisChainId, nil
}

func createSubnet(w *wallet) (ids.ID, error) {
	ctx := context.Background()
	addr := genesis.EWOQKey.PublicKey().Address()
	createSubnetTx, err := w.p.IssueCreateSubnetTx(
		&secp256k1fx.OutputOwners{
			Threshold: 1,
			Addrs:     []ids.ShortID{addr},
		},
		common.WithContext(ctx),
		defaultPoll,
	)
	if err != nil {
		return ids.Empty, err
	}

	return createSubnetTx.ID(), nil
}

func newWallet(uri string) (*wallet, error) {
	ctx := context.Background()
	kc := secp256k1fx.NewKeychain(genesis.EWOQKey)

	// MakeWallet fetches the available UTXOs owned by [kc] on the network that
	// [uri] is hosting.
	walletSyncStartTime := time.Now()
	createdWallet, err := primary.MakeWallet(ctx, &primary.WalletConfig{
		URI:          uri,
		AVAXKeychain: kc,
		EthKeychain:  kc,
	})
	if err != nil {
		log.Fatalf("failed to initialize wallet: %s\n", err)
	}
	log.Printf("synced wallet in %s\n", time.Since(walletSyncStartTime))

	return &wallet{
		p: createdWallet.P(),
		x: createdWallet.X(),
		c: createdWallet.C(),
	}, nil
}
