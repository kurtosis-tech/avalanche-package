DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego:v1.9.11-Subnet-EVM-master"

def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        result[attr] = attr
    return result

def get_default_input_args():
    default_node_cfg = get_default_node_cfg()
    return {
        "node_name": "node1",
        "avalanchego_image": DEFAULT_AVALANCHEGO_IMAGE,
        "node_config": default_node_cfg,
    }

def get_default_node_cfg():
    return {
        "network-id": "local",
        "staking-enabled": False,
        "health-check-frequency": "5s",
    }