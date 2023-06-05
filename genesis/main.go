package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"github.com/ava-labs/avalanchego/genesis"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/staking"
	"github.com/ava-labs/avalanchego/utils/perms"
	"net"
	"os"
	"strconv"
)

const (
	stakingNodeKeyPath  = "/tmp/data/node-%d/staking/staker.key"
	stakingNodeCertPath = "/tmp/data/node-%d/staking/staker.crt"
	nodeIdPath          = "/tmp/data/node-%d/node_id.txt"
	genesisFile         = "/tmp/data/genesis.json"
	numNodeArgIndex     = 2
	networkIdIndex      = 1
	minRequiredArgs     = numNodeArgIndex + 1
	nonZeroExitCode     = 1
)

func main() {
	if len(os.Args) < minRequiredArgs {
		fmt.Printf("Need at least %v args got '%v' total\n", minRequiredArgs, len(os.Args))
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
		os.WriteFile(fmt.Sprintf(nodeIdPath, index), []byte(nodeId.String()), perms.ReadOnly)
		fmt.Printf("node '%v' has node id '%v'\n", index, nodeId)
		genesisValidators = append(genesisValidators, nodeId)
	}

	fmt.Printf("generated '%v' nodes\n", len(genesisValidators))

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
	genesisJson, _ := json.Marshal(unparsedConfig)

	os.WriteFile(genesisFile, genesisJson, perms.ReadOnly)

	// TODO write this to a file and use these IP addresses
	ipAddresses, err := getNextIpAddresses("lo0", numNodes)
	fmt.Println(ipAddresses)
	fmt.Println(err)

	fmt.Printf("generated genesis data at '%v'\n", genesisFile)
}

// this is a hack to pre populate bootstrap ip addresses
func getNextIpAddresses(interfaceName string, numNodes int) (addr []string, err error) {
	var (
		ief      *net.Interface
		addrs    []net.Addr
		ipv4Addr net.IP
	)
	if ief, err = net.InterfaceByName(interfaceName); err != nil { // get interface
		return
	}
	if addrs, err = ief.Addrs(); err != nil { // get addresses
		return
	}
	for _, addr := range addrs { // get ipv4 address
		if ipv4Addr = addr.(*net.IPNet).IP.To4(); ipv4Addr != nil {
			break
		}
	}
	if ipv4Addr == nil {
		return nil, errors.New(fmt.Sprintf("interface %s don't have an ipv4 address\n", interfaceName))
	}

	var addresses []string
	ip := ipv4Addr.To4()
	ip = ip.Mask(ip.DefaultMask())
	for index := 0; index < numNodes; index++ {
		ip[3]++
		addresses = append(addresses, ip.String())
	}

	return addresses, nil
}
