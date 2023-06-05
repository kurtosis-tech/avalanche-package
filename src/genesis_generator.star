static_files = import_module("github.com/kurtosis-tech/avalanche-package/static_files/static_files.star")

GO_IMG = "golang:1.20.4"
ABS_PLUGIN_DIRPATH = "/avalanchego/build/plugins/"

def create_genesis(plan, network_id, num_nodes):

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

    plan.add_service(
        name="genesis",
        config=ServiceConfig(
            image = GO_IMG,
            entrypoint=["sleep", "99999"],
            files={
                "/tmp/genesis": genesis_generator,
                "/tmp/config": node_cfg,
            }
        )
    )

    for index in range(0, num_nodes):
        plan.exec(
            service_name = "genesis",
            recipe = ExecRecipe(
                command = ["cp", "/tmp/config/config.json", "/tmp/data/node-{0}/config.json".format(index)]
            )
        )

    plan.exec(
        service_name="genesis",
        recipe=ExecRecipe(
            command=[
                "/bin/sh", "-c", "cd /tmp/genesis && go run main.go {0} {1}".format(network_id, num_nodes)]
        )
    )

    genesis_data = plan.store_service_files(
        service_name = "genesis",
        src = "/tmp/data"
    )

    return genesis_data