:small_red_triangle: Avalanche Package
======================================

This is a [Kurtosis package](https://docs.kurtosis.com/concepts-reference/packages) that spins up a non-staking Avalanche node. You may optionally specify the number of nodes you wish to start locally with a simple `arg` passed in at execution time.

Run this package
----------------
Open [the Kurtosis playground](https://gitpod.io/#/https://github.com/kurtosis-tech/playground-gitpod) and run:

```bash
kurtosis run github.com/kurtosis-tech/avalanche-package
```
To run it locally, [install Kurtosis][install-kurtosis] and run the same.

To blow away the created [enclave][enclaves-reference], run `kurtosis clean -a`.

## Configuration

<!-- You can parameterize your package as you prefer; see https://docs.kurtosis.com/next/concepts-reference/args for more -->
You can configure this package using the following JSON structure (keys and default values):

```javascript
{
    "dont_start_subnets": False,
    "is_elastic": False,
    "ephemeral_ports": True,
    "avalanchego_image": "avaplatform/avalanchego:v1.10.1-Subnet-EVM-master",
    "node_config": {
        "network-id": "1337",
        "staking-enabled": False,
        "health-check-frequency": "5s",        
    },
    "node_count": 5,
    "min_cpu": 0,
    "min_memory": 0,
    "vm_name": "testNet",
    "chain_name": "testChain",
    "custom_subnet_vm_path": "",
    "custom_subnet_vm_url": "",
    "subnet_genesis_json": "github.com/kurtosis-tech/avalanche-package/static_files/genesis.json"
}
```

For example:
Running:
```bash
kurtosis run github.com/kurtosis-tech/avalanche-package '{"node_count":3}'
```
will spin up 3 non-stacking Avalanche nodes locally.


| Key                 | Meaning                                                                                                                |
| ------------------- | -----------------------------------------------------------------------------------------------------------------------|
| dont_start_subnets  | If set to true; Kurtosis won't start subnets (default: False)                                                          |
| is_elastic          | If set to true; Kurtosis will start elastic subnets (default: False)                                                   |
| ephemeral_ports     | Docker only. If set to false Kurtosis will expose ports 9650, 9652 and so on for rpc ports and 9651, 9653 and so on for staking (default: true)|
| avalanchego_image   | The image to start the node with (default: avaplatform/avalanchego:v1.10.1-Subnet-EVM-master)|
| node_count  | Number of nodes to start the cluster with (default: 5) |
| node_config.network-id  | The ID of the primary network to spin up |
| node_config.staking-enabled  | Whether staking is enabled on the node |
| node_config.health-check-frequency  | Interval at which to check health |
| num_validators  | Number of validator nodes to start the cluster with. (default: node_count)         |
| min_cpu  | K8S only. Minimum cpu in millicores per avalanche node that Kurtosis spins up (default: 0)         |
| min_memory  | K8S only. Minimum memory in megabytes per avalanche node that Kurtosis spins up (default: 0)         |
| vm_name  | The name to assign to the VM and dervie vm id from (default: testNet)         |
| chain name  | The alias to assign to the chain (default: testChain)         |
| custom_subnet_vm_path  | If supplied Kurtosis will use this as the VM to use for the subnet it spins up|
| custom_subnet_vm_url  | If supplied Kurtosis will download and use this as the VM to use for the subnet it spins up|
| subnet_genesis_json  | If you are using this package from a different package you can override the default genesis for the subnet using this argument|


## Custom Subnet Genesis

By default Kurtosis runs the subnet chain with the `genesis.json` at `static_files/genesis.json`. To bring your own `genesis.json` you should - 

1. Clone the repository
2. Replace that file with the right values
3. Run the package with `kurtosis run .` to ensure that you are running local code
4. Optionally you can publish this to a fork and use that with `kurtosis run` passing a remote GitHub path

By updating the `genesis.json` you can change the initial allocations, chain id, gas configuration and a lot of other config

Various different [precompiles](https://docs.avax.network/subnets/customize-a-subnet#precompiles) can also be configured by bringing your own genesis.json

## Non Ephemeral Ports

Use the `{"ephemeral_ports": false}` argument to get non ephemeral ports, rpc ports will be on 9650, 9652, 9654 and so on while non staking ports will be on 9651, 9653, 9655 and so on.

Use this package in your package
--------------------------------
Kurtosis packages can be composed inside other Kurtosis packages.  Assuming you want to spin up an Avalanche node and your own service
together, you just need to do the following in your own package:


```python
# First, import this package by adding the following to the top of your package's Starlark file:
this_package = import_module("github.com/kurtosis-tech/avalanche-package/main.star")
```

Then, call the this package's `run` function later in your package's Starlark script:

```python
this_package_output = this_package.run(plan, args)
```

By using the `subnet_genesis_json` argument you can pass the url of a `genesis.json` in your own package to use a different genesis file for the subnet.

## Kubernetes Configuration

To run this on Kubernetes you need to configure your CLI to work with Kubernetes using [this guide](https://docs.kurtosis.com/k8s/)

Further the chain rpc url that gets printed at the end won't be directly accessible as the IP address printed there is internal to `K8S`; you will have to replace
the URL slightly like given the following input - 

`http://172.16.5.3:9650/ext/bc/2hzMp2mNsBpCHRMkyaM6gR1tgeV4sTGuDx8WD2uG5LwTEPfpZe/rpc`

Keep everything but replace the ip address with `127.0.0.1` and the port `9650` with any of the rpc ports listed in `kurtosis enclave inspect`. As an example

```
========================================== User Services ==========================================
UUID           Name      Ports                                  Status
426da692eea4   builder   <none>                                 RUNNING
09d0bbc70f9b   node-0    rpc: 9650/tcp -> 127.0.0.1:61837       RUNNING
                         staking: 9651/tcp -> 127.0.0.1:61838
cd172a584033   node-1    rpc: 9650/tcp -> 127.0.0.1:61839       RUNNING
                         staking: 9651/tcp -> 127.0.0.1:61840
0d6a4daf23ee   node-2    rpc: 9650/tcp -> 127.0.0.1:61834       RUNNING
                         staking: 9651/tcp -> 127.0.0.1:61835
```

The final url would look like `http://127.0.0.1:61834/ext/bc/2hzMp2mNsBpCHRMkyaM6gR1tgeV4sTGuDx8WD2uG5LwTEPfpZe/rpc`

Develop on this package
-----------------------
1. [Install Kurtosis][install-kurtosis]
1. Clone this repo
1. For your dev loop, run `kurtosis clean -a && kurtosis run .` inside the repo directory


<!-------------------------------- LINKS ------------------------------->
[install-kurtosis]: https://docs.kurtosis.com/install
[enclaves-reference]: https://docs.kurtosis.com/concepts-reference/enclaves
