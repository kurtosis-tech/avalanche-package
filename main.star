node_launcher = import_module("github.com/kurtosis-tech/avalanche-package/src/node_launcher.star")
builder_service = import_module("github.com/kurtosis-tech/avalanche-package/src/builder.star")
input_parser = import_module("github.com/kurtosis-tech/avalanche-package/src/package_io/input_parser.star")

def run(plan, args):
    args_with_right_defaults = input_parser.parse_input(args)
    expose_9650_if_one_node = args.get("test_mode", False)
    node_count = args_with_right_defaults["node_count"]
    # make this passable and match the node config in node_launcher
    builder = builder_service.init(plan, "1337")
    genesis = builder.genesis(plan, "1337" ,node_count)
    rpc_urls = node_launcher.launch(plan, genesis, args_with_right_defaults["avalanchego_image"], node_count, expose_9650_if_one_node)
    first_url = rpc_urls[0]
    subnetId, chainId, vmId, validatorIds = builder.create_subnet(plan, first_url, node_count)
    plan.print(subnetId, chainId, vmId, validatorIds)
    return nodes
