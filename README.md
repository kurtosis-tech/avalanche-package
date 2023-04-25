Avalanche Package
===========================

This is a Kurtosis Starlark Package that spins up a single non staking Avalanche node.

### Run

This assumes you have the [Kurtosis CLI](https://docs.kurtosis.com/cli/) installed and the [Docker daemon](https://docs.kurtosis.com/install#i-install--start-docker) running on your local machine.

To get started, simply run
```bash
kurtosis run github.com/kurtosis-tech/avalanche-package
```

### Using this in your own package

Kurtosis Packages can be used within other Kurtosis Packages through [composition](https://docs.kurtosis.com/reference/packages). Assuming you want to spin up an Avalanche node and your own service
together, you just need to do the following

```py
# Import the Avalanche Package
avalanche_node_module = import_module("github.com/kurtosis-tech/avalanche-package/main.star")

# main.star of your Avalanche node + Service package
def run(plan, args):
    plan.print("Spinning up the Avalanche node")
    # this will spin up the node and return the output of the Avalanche Network package
    # any args parsed to your package would get passed down to the Ethereum Network package
    avalanche_node = avalanche_node_module.run(plan, args)
```
