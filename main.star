node_launcher = import_module("./src/node_launcher.star")
builder_service = import_module("./src/builder.star")
input_parser = import_module("./src/package_io/input_parser.star")

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
    num_validators = args_with_right_defaults["num_validators"]
    node_config = args_with_right_defaults["node_config"]
    custom_subnet_vm_path = args_with_right_defaults["custom_subnet_vm_path"]
    custom_subnet_vm_url = args_with_right_defaults["custom_subnet_vm_url"]
    subnet_genesis_json = args_with_right_defaults["subnet_genesis_json"]
    plan.print("Using arguments:\n{0}".format(json.indent(json.encode(args_with_right_defaults))))
    if custom_subnet_vm_path and custom_subnet_vm_url:
        fail("both {0} and {1} were set. only one can be set at a time.", "custom_subnet_vm_path", "custom_subnet_vm_url")
    networkId = node_config["network-id"]
    if not ephemeral_ports:
        plan.print("Warning - Ephemeral ports have been disabled will be publishing first node rpc on 9650 and staking on 9651, this can break due to port clash!")
    builder_service.init(plan, node_config, subnet_genesis_json)
    genesis, vmId = builder_service.genesis(plan, networkId ,node_count, vmName)
    rpc_urls, public_rpc_urls, launch_commands = node_launcher.launch(plan, genesis, image, node_count, ephemeral_ports, min_cpu, min_memory, vmId, dont_start_subnets, custom_subnet_vm_path, custom_subnet_vm_url)
    first_private_rpc_url = rpc_urls[0]
    if public_rpc_urls:
        rpc_urls = public_rpc_urls
    output = {}
    output["rpc-urls"] = rpc_urls
    if not dont_start_subnets:
        subnetId, chainId, validatorIds, allocations, genesisChainId, assetId, transformationId, exportId, importId = builder_service.create_subnet(plan, first_private_rpc_url, num_validators, is_elastic, vmId, chainName)
        plan.print("subnet id: {0}\nchain id: {1}\nvm id: {2}\nvalidator ids: {3}\n".format(subnetId, chainId, vmId, ", ".join(validatorIds)))
        node_launcher.restart_nodes(plan, node_count, launch_commands, subnetId, vmId)
        output["rpc-urls"] = rpc_urls
        output["subnet id"] = subnetId
        output["chain id"] = chainId
        output["vm id"] = vmId
        output["validator ids"] = validatorIds
        output["chain-rpc-url"] = "{0}/ext/bc/{1}/rpc".format(rpc_urls[0], chainId)
        output["allocations"] = allocations
        output["chain genesis id"] = genesisChainId
        if is_elastic:
            output["elastic config"] = {}
            output["elastic config"]["asset id"] = assetId
            output["elastic config"]["transformation id"] = transformationId
            output["elastic config"]["export id"] = exportId
            output["elastic config"]["import id"] = importId
            output["elastic config"]["token symbol"] = "FOO"
    return output