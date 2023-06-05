package main

import (
	"fmt"
	"github.com/ava-labs/avalanche-network-runner/network"
	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/staking"
	"math/big"
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

	//balance := 0x295BE96E64066972000000
	value := new(big.Int)
	value.SetString("0x295BE96E64066972000000", 0)
	var cChainBalances []network.AddrAndBalance
	ewoqAddrAndBalance := network.AddrAndBalance{
		Addr:    genesis.EWOQKey.Address(),
		Balance: value,
	}
	cChainBalances = append(cChainBalances, ewoqAddrAndBalance)

	jsonBytes, err := network.NewAvalancheGoGenesis(uint32(networkId), nil, cChainBalances, genesisValidators)
	if err != nil {
		fmt.Printf("an error occurred while generating genesis.json: %v", err)
		os.Exit(nonZeroExitCode)
	}
	fmt.Println(string(jsonBytes))
}
