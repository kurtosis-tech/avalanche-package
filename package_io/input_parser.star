DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego"

def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        value = input_args[attr]
        if attr in input_args:
                result[attr] = value

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