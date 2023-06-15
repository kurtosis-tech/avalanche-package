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
    dont_start_subnets = args_with_right_defaults["dont_start_subnets"]
    min_cpu =  args_with_right_defaults["min_cpu"]
    min_memory =  args_with_right_defaults["min_memory"]
    vmName = args_with_right_defaults["vm_name"]
    chainName = args_with_right_defaults["chain_name"]
    if not ephemeral_ports:
        plan.print("Warning - Ephemeral ports have been disabled will be publishing first node rpc on 9650 and staking on 9651, this can break due to port clash!")
    # TODO make network_id 1337 passable and match the node config in node_launcher
    builder_service.init(plan, "1337")
    genesis, vmId = builder_service.genesis(plan, "1337" ,node_count, vmName)
    rpc_urls, public_rpc_urls, launch_commands = node_launcher.launch(plan, genesis, args_with_right_defaults["avalanchego_image"], node_count, ephemeral_ports, min_cpu, min_memory)
    first_private_rpc_url = rpc_urls[0]
    if public_rpc_urls:
        rpc_urls = public_rpc_urls
    output = {}
    output["rpc-urls"] = rpc_urls
    if not dont_start_subnets:
        subnetId, chainId, validatorIds, assetId, transformationId, exportId, importId = builder_service.create_subnet(plan, first_private_rpc_url, node_count, is_elastic, vmId, chainName)
        plan.print("subnet id: {0}\nchain id: {1}\nvm id: {2}\nvalidator ids: {3}\n".format(subnetId, chainId, vmId, ", ".join(validatorIds)))
        node_launcher.restart_nodes(plan, node_count, launch_commands, subnetId, vmId)
        output["rpc-urls"] = rpc_urls
        output["subnet id"] = subnetId
        output["chain id"] = chainId
        output["vm id"] = vmId
        output["validator ids"] = validatorIds
        output["chain-rpc-url"] = "{0}/ext/bc/{1}/rpc".format(rpc_urls[0], chainId)
        # TODO remove this as this is hardcoded
        output["chain genesis id"] = "13123"
        if is_elastic:
            output["elastic config"] = {}
            output["elastic config"]["asset id"] = assetId
            output["elastic config"]["transformation id"] = transformationId
            output["elastic config"]["export id"] = exportId
            output["elastic config"]["import id"] = importId
            output["elastic config"]["token symbol"] = "FOO"
    return output