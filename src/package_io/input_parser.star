DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego:v1.10.1-Subnet-EVM-master"

def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        result[attr] = input_args[attr]
    result["num_validators"] = result.get("num_validators", result["node_count"])
    return result

def get_default_input_args():
    default_node_cfg = get_default_node_cfg()
    return {
        "dont_start_subnets": False,
        "is_elastic": False,
        "ephemeral_ports": True,
        "avalanchego_image": DEFAULT_AVALANCHEGO_IMAGE,
        "node_config": default_node_cfg,
        "node_count": 5,
        # in milli cores 1000 millicores is 1 core
        "min_cpu": 0,
        # in megabytes
        "min_memory": 0,
        "vm_name": "testNet",
        "chain_name": "testChain",  
        "network_id": "1337"
    }

# TODO figure out why stakng is disabled
def get_default_node_cfg():
    return {
        "network-id": "1337",
        "staking-enabled": False,
        "health-check-frequency": "5s",
    }