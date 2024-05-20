DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego:v1.11.5"


def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        result[attr] = input_args[attr]
    if result["node_count"] < 2:
        fail("node_count must be at least 2")
    result["num_validators"] = result.get("num_validators", result["node_count"])
    # if both custom_subnet_vm_path and custom_subnet_vm_url are provided, throw error
    if result["custom_subnet_vm_path"] and result["custom_subnet_vm_url"]:
        fail("Only one of custom_subnet_vm_path and custom_subnet_vm_url can be provided")
    return result


def get_default_input_args():
    default_node_cfg = get_default_node_cfg()
    return {
        "dont_start_subnets": False,
        "is_elastic": False,
        "ephemeral_ports": True,
        "avalanchego_image": DEFAULT_AVALANCHEGO_IMAGE,
        "node_config": default_node_cfg,
        "node_count": 2,
        # in milli cores 1000 millicores is 1 core
        "min_cpu": 0,
        # in megabytes
        "min_memory": 0,
        "vm_name": "testNet",
        "chain_name": "testChain",
        "custom_subnet_vm_path": "",
        "custom_subnet_vm_url": "https://github.com/ava-labs/subnet-evm/releases/download/v0.6.4/subnet-evm_0.6.4_linux_amd64.tar.gz",
        "subnet_genesis_json": "/static_files/genesis.json"
    }


def get_default_node_cfg():
    return {
        "network-id": "1337",
        "staking-enabled": False,
        "health-check-frequency": "5s",
    }
