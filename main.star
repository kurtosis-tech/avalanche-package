node_launcher = import_module("github.com/kurtosis-tech/avalanche-package/src/node_launcher.star")
builder_service = import_module("github.com/kurtosis-tech/avalanche-package/src/builder.star")
input_parser = import_module("github.com/kurtosis-tech/avalanche-package/src/package_io/input_parser.star")

def run(plan, args):
    args_with_right_defaults = input_parser.parse_input(args)
    expose_9650_if_one_node = args.get("test_mode", False)
    node_count = args_with_right_defaults["node_count"]
    image = args_with_right_defaults["avalanchego_image"]
    ephemeral_ports = args_with_right_defaults["ephemeral_ports"]
    is_elastic = args_with_right_defaults["is_elastic"]
    if not ephemeral_ports:
        plan.print("Warning - Ephemeral ports have been disabled will be publishing first node rpc on 9650 and staking on 9651, this can break due to port clash!")
    # make network_id 1337 passable and match the node config in node_launcher
    builder_service.init(plan, "1337")
    genesis = builder_service.genesis(plan, "1337" ,node_count)
    rpc_urls, public_rpc_urls, launch_commands = node_launcher.launch(plan, genesis, args_with_right_defaults["avalanchego_image"], node_count, ephemeral_ports)
    first_private_rpc_url = rpc_urls[0]
    subnetId, chainId, vmId, validatorIds = builder_service.create_subnet(plan, first_private_rpc_url, node_count, is_elastic)
    plan.print("subnet id: {0}\nchain id: {1}\nvm id: {2}\nvalidator ids: {3}\n".format(subnetId, chainId, vmId, ", ".join(validatorIds)))
    node_launcher.restart_nodes(plan, node_count, launch_commands, subnetId, vmId)
    if public_rpc_urls:
        rpc_urls = public_rpc_urls
    return {
        "rpc-urls": rpc_urls,
        "subnet id": subnetId,
        "chain id": chainId,
        "vm id": vmId,
        "validator ids": validatorIds,
        "chain-rpc-url": "{0}/ext/bc/{1}/rpc".format(rpc_urls[0], chainId)
}
