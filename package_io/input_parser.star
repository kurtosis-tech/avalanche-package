DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego:latest"

def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        result[attr] = input_args[attr]
    return result

def get_default_input_args():
    default_node_cfg = get_default_node_cfg()
    return {
        "node_name_prefix": "node-",
        "avalanchego_image": DEFAULT_AVALANCHEGO_IMAGE,
        "node_config": default_node_cfg,
        "node_count": 1
    }

def get_default_node_cfg():
    return {
        "network-id": "local",
        "staking-enabled": False,
        "health-check-frequency": "5s",
    }