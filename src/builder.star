static_files = import_module("./static_files_locators.star")
utils = import_module("./utils.star")

GO_IMG = "golang:1.22.2"
ABS_PLUGIN_DIRPATH = "/avalanchego/build/plugins/"

BUILDER_SERVICE_NAME = "builder"

def init(plan, node_cfg, subnet_genesis_json):

    node_cfg_template = read_file(static_files.NODE_CFG_JSON_FILEPATH)
    cfg_template_data = {
        "PluginDirPath": ABS_PLUGIN_DIRPATH,
        "NetworkId": node_cfg["network-id"],
        "StakingEnabled": node_cfg["staking-enabled"],
        "HealthCheckFrequency": node_cfg["health-check-frequency"],
    }
    node_cfg = plan.render_templates(
        config= {
            "config.json": struct(
                template = node_cfg_template,
                data = cfg_template_data,
            ),
        }
    )

    genesis_generator = plan.upload_files(
        "../genesis")

    wallet = plan.upload_files(
        "../wallet")

    subnet_genesis = plan.upload_files(subnet_genesis_json)

    plan.add_service(
        name=BUILDER_SERVICE_NAME,
        config=ServiceConfig(
            image = GO_IMG,
            entrypoint=["sleep", "99999"],
            files={
                "/tmp/genesis": genesis_generator,
                "/tmp/config": node_cfg,
                "/tmp/wallet": wallet,
                "/tmp/subnet-genesis/": subnet_genesis
            }
        )
    )


def genesis(plan, network_id, num_nodes, vmName):
    plan.exec(
        service_name=BUILDER_SERVICE_NAME,
        recipe=ExecRecipe(
            command=[
                "/bin/sh", "-c", "cd /tmp/genesis && go run main.go {0} {1} {2}".format(network_id, num_nodes, vmName)]
        )
    )

    for index in range(0, num_nodes):
        plan.exec(
            service_name = BUILDER_SERVICE_NAME,
            recipe = ExecRecipe(
                command = ["cp", "/tmp/config/config.json", "/tmp/data/node-{0}/config.json".format(index)]
            )
        )

    genesis_data = plan.store_service_files(
        service_name = BUILDER_SERVICE_NAME,
        src = "/tmp/data"
    )

    vmId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/data/vmId.txt")

    return genesis_data, vmId


def create_subnet(plan, uri, num_nodes, is_elastic, vmId, chainName):
    plan.exec(
        service_name = BUILDER_SERVICE_NAME,
        recipe = ExecRecipe(
            command = ["/bin/sh", "-c", "cd /tmp/wallet && go run main.go {0} {1} {2} {3} {4}".format(uri, vmId, chainName, num_nodes, is_elastic)]
        )
    )

    subnetId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/subnetId.txt")
    chainId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/chainId.txt")
    allocations = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/allocations.txt")
    genesisChainId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/genesisChainId.txt")

    assetId, transformationId, exportId, importId = None, None, None, None
    if is_elastic:
        assetId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/assetId.txt")
        transformationId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/transformationId.txt")
        exportId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/exportId.txt")
        importId = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/importId.txt")


    validatorIds = []
    for index in range (0, num_nodes):
        validatorIds.append(utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, "/tmp/subnet/node-{0}/validator_id.txt".format(index)))
    
    return subnetId, chainId, validatorIds, allocations, genesisChainId, assetId, transformationId, exportId, importId