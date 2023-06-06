static_files = import_module("github.com/kurtosis-tech/avalanche-package/static_files/static_files.star")

GO_IMG = "golang:1.20.4"
ABS_PLUGIN_DIRPATH = "/avalanchego/build/plugins/"

BUILDER_SERVICE_NAME = "builder"

def init(plan, network_id):

    node_cfg_template = read_file(static_files.NODE_CFG_JSON_FILEPATH)
    cfg_template_data = {
        "PluginDirPath": ABS_PLUGIN_DIRPATH,
        "NetworkId": network_id,
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
        "github.com/kurtosis-tech/avalanche-package/genesis")

    wallet = plan.upload_files(
        "github.com/kurtosis-tech/avalanche-package/wallet")        

    plan.add_service(
        name=BUILDER_SERVICE_NAME,
        config=ServiceConfig(
            image = GO_IMG,
            entrypoint=["sleep", "99999"],
            files={
                "/tmp/genesis": genesis_generator,
                "/tmp/config": node_cfg,
                "/tmp/wallet": wallet
            }
        )
    )

def genesis(plan, network_id, num_nodes):
    plan.exec(
        service_name=BUILDER_SERVICE_NAME,
        recipe=ExecRecipe(
            command=[
                "/bin/sh", "-c", "cd /tmp/genesis && go run main.go {0} {1}".format(network_id, num_nodes)]
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

    return genesis_data