# Wallet Main

This is the main entry point for the wallet application in the Avalanche project. The main function in `main.go` is
responsible for creating and managing subnets in the Avalanche network.

## Usage

The `main.go` file is typically run with the following command:

```bash
go run main.go {uri} {vmId} {chainName} {num_nodes} {is_elastic}
```
Where:

- `{uri}`: The URI for the Avalanche network.
- `{vmId}`: The ID of the VM where the subnet will be created.
- `{chainName}`: The name of the chain where the subnet will be created.
- `{num_nodes}`: The number of nodes in the subnet.
- `{is_elastic}`: A boolean value indicating whether the subnet is elastic.

It's usage when being called from the main.star file is:
```starlark
builder_service.create_subnet(
    plan, first_private_rpc_url, num_validators, is_elastic, vmId, chainName)
```

It's return values are:

- subnetId 
- chainId
- validatorIds 
- allocations 
- genesisChainId 
- assetId 
- transformationId 
- exportId 
- importId

## Output

The `main.go` function writes several output files to the `/tmp/subnet/` directory:

- `subnetId.txt`: Contains the ID of the created subnet.
- `chainId.txt`: Contains the ID of the chain where the subnet was created.
- `allocations.txt`: Contains allocation information for the subnet.
- `genesisChainId.txt`: Contains the ID of the genesis chain for the subnet.

If the subnet is elastic, the following additional files are created:

- `assetId.txt`: Contains the ID of the asset associated with the subnet.
- `transformationId.txt`: Contains the ID of the transformation associated with the subnet.
- `exportId.txt`: Contains the ID of the export associated with the subnet.
- `importId.txt`: Contains the ID of the import associated with the subnet.

For each node in the subnet, a `validator_id.txt` file is created in the `/tmp/subnet/node-{index}/` directory, where `{index}` is the index of the node. This file contains the ID of the validator for the node.

## Dependencies

The `main.go` file depends on several packages from the Avalanche project, including:

- `github.com/ava-labs/avalanchego/genesis`
- `github.com/ava-labs/avalanchego/ids`
- `github.com/ava-labs/avalanchego/utils/constants`
- `github.com/ava-labs/avalanchego/vms/avm`
- `github.com/ava-labs/avalanchego/vms/platformvm`
- `github.com/ava-labs/avalanchego/vms/secp256k1fx`
- `github.com/ava-labs/avalanchego/wallet/chain/p`
- `github.com/ava-labs/avalanchego/wallet/chain/p/builder`
- `github.com/ava-labs/avalanchego/wallet/chain/p/signer`
- `github.com/ava-labs/avalanchego/wallet/chain/x`
- `github.com/ava-labs/avalanchego/wallet/subnet/primary`
- `github.com/ava-labs/avalanchego/wallet/subnet/primary/common`