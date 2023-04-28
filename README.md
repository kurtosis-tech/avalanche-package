Avalanche Package
===========================

This is a [Kurtosis package](https://docs.kurtosis.com/concepts-reference/packages) that spins up a non-staking Avalanche node. You may optionally specify the number of nodes you wish to start locally with a simple `arg` passed in at execution time.

Run this package
----------------
Open [the Kurtosis playground](https://gitpod.io/#/https://github.com/kurtosis-tech/playground-gitpod) and run:

```bash
kurtosis run github.com/kurtosis-tech/avalanche-package
```
To run it locally, [install Kurtosis][install-kurtosis] and run the same.

To blow away the created [enclave][enclaves-reference], run `kurtosis clean -a`.

#### Configuration

<details>
    <summary>Click to see configuration</summary>

<!-- You can parameterize your package as you prefer; see https://docs.kurtosis.com/next/concepts-reference/args for more -->
You can configure this package using the following JSON structure:

```javascript
{
    "name": "John Snow"
}
```

For example:
Running:
```bash
kurtosis run github.com/kurtosis-tech/avalanche-package '{"node_count":3}'
```
will spin up 3 non-stacking Avalanche nodes locally.

</details>

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

Develop on this package
-----------------------
1. [Install Kurtosis][install-kurtosis]
1. Clone this repo
1. For your dev loop, run `kurtosis clean -a && kurtosis run .` inside the repo directory


<!-------------------------------- LINKS ------------------------------->
[install-kurtosis]: https://docs.kurtosis.com/install
[enclaves-reference]: https://docs.kurtosis.com/concepts-reference/enclaves
