node_launcher = import_module("github.com/kurtosis-tech/avalanche-package/src/node_launcher.star")
builder_service = import_module("github.com/kurtosis-tech/avalanche-package/src/builder.star")
input_parser = import_module("github.com/kurtosis-tech/avalanche-package/src/package_io/input_parser.star")

def run(plan, args):
    args_with_right_defaults = input_parser.parse_input(args)
    expose_9650_if_one_node = args.get("test_mode", False)
    node_count = args_with_right_defaults["node_count"]
    # make network_id 1337 passable and match the node config in node_launcher
    builder_service.init(plan, "1337")
    genesis = builder_service.genesis(plan, "1337" ,node_count)
    rpc_urls, launch_commands = node_launcher.launch(plan, genesis, args_with_right_defaults["avalanchego_image"], node_count, expose_9650_if_one_node)
    first_url = rpc_urls[0]
    subnetId, chainId, vmId, validatorIds = builder_service.create_subnet(plan, first_url, node_count)
    plan.print("{0}\n{1}\n{2}\n{3}\n".format(subnetId, chainId, vmId, ", ".join(validatorIds)))
    node_launcher.restart_nodes(plan, node_count, launch_commands, subnetId, vmId)
    return rpc_urls
