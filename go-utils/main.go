package main

import (
	"encoding/json"
	"fmt"
	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/staking"
	"os"
	"strconv"
)

const (
	stakingNodeKeyPath  = "/tmp/data/staking/node-%d/staker.key"
	stakingNodeCertPath = "/tmp/data/staking/node-%d/staker.cert"
	numNodeArgIndex     = 2
	networkIdIndex      = 1
	nonZeroExitCode     = 1
)

func main() {
	if len(os.Args) < networkIdIndex {
		fmt.Printf("Need at least 2 more args apart from program name got '%v' total\n", len(os.Args))
		os.Exit(nonZeroExitCode)
	}

	numNodesArg := os.Args[numNodeArgIndex]
	numNodes, err := strconv.Atoi(numNodesArg)
	if err != nil {
		fmt.Printf("An error occurred while converting numNodes arg to integer: %v\n", err)
		os.Exit(nonZeroExitCode)
	}

	networkIdArg := os.Args[networkIdIndex]
	networkId, err := strconv.Atoi(networkIdArg)
	if err != nil {
		fmt.Printf("An error occurred while converting networkId arg to integer: %v\n", err)
		os.Exit(nonZeroExitCode)
	}

	fmt.Printf("Have a total of '%v' nodes to generate and network id '%v'\n", numNodes, networkId)
	// Every Node is a validator node for now
	var genesisValidators []ids.NodeID

	for index := 0; index < numNodes; index++ {
		keyPath := fmt.Sprintf(stakingNodeKeyPath, index)
		certPath := fmt.Sprintf(stakingNodeCertPath, index)
		err = staking.InitNodeStakingKeyPair(keyPath, certPath)
		if err != nil {
			fmt.Printf("An error occurred while generating keys for node %v: %v\n", index, err)
			os.Exit(nonZeroExitCode)
		}
		fmt.Printf("Gnerated key and cert for node '%v' at '%v', '%v\n", index, keyPath, certPath)
		cert, err := staking.LoadTLSCertFromFiles(keyPath, certPath)
		if err != nil {
			fmt.Printf("an error occurred while loading cert pair for node '%v': %v\n", index, err)
			os.Exit(nonZeroExitCode)
		}
		nodeId := ids.NodeIDFromCert(cert.Leaf)
		fmt.Printf("node '%v' has node id '%v'\n", index, nodeId)
		genesisValidators = append(genesisValidators, nodeId)
	}

	fmt.Println(genesisValidators)

	genesisConfig := genesis.GetConfig(uint32(networkId))
	unparsedConfig, _ := genesisConfig.Unparse()

	var initialStakers []genesis.UnparsedStaker
	basicDelegationFee := 62500
	// give staking reward to random address
	for _, nodeId := range genesisValidators {
		staker := genesis.UnparsedStaker{
			NodeID:        nodeId,
			RewardAddress: unparsedConfig.Allocations[1].AVAXAddr,
			DelegationFee: uint32(basicDelegationFee),
		}
		basicDelegationFee = basicDelegationFee * 2
		initialStakers = append(initialStakers, staker)
	}

	unparsedConfig.InitialStakers = initialStakers
	unparsedConfig.Message = "do or do not; there is no try"
	genesisJson, _ := json.Marshal(unparsedConfig)
	fmt.Println(string(genesisJson))
}
