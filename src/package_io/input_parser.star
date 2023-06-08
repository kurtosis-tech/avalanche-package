DEFAULT_AVALANCHEGO_IMAGE = "avaplatform/avalanchego:v1.10.1-Subnet-EVM-master"

def parse_input(input_args):
    result = get_default_input_args()
    for attr in input_args:
        result[attr] = input_args[attr]
    return result

def get_default_input_args():
    default_node_cfg = get_default_node_cfg()
    return {
        "is_elastic": True,
        "ephemeral_ports": True,
        "avalanchego_image": DEFAULT_AVALANCHEGO_IMAGE,
        "node_config": default_node_cfg,
        "node_count": 5
    }

# TODO figure out why stakng is disabled
def get_default_node_cfg():
    return {
        "network-id": "1337",
        "staking-enabled": False,
        "health-check-frequency": "5s",
    }