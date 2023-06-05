package main

import (
	"fmt"
	"github.com/ava-labs/avalanchego/staking"
)

const (
	stakingNodeKeyPath  = "/tmp/data/staking/staker.key"
	stakingNodeCertPath = "/tmp/data/staking/staker.cert"
)

func main() {
	err := staking.InitNodeStakingKeyPair(stakingNodeKeyPath, stakingNodeCertPath)
	fmt.Println(err)
}
