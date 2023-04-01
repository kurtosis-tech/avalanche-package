static_files = import_module("github.com/kurtosis-tech/avalanche-package/static_files)

RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"

BUILD_DIRPATH = "."
PLUGIN_DIRPATH = BUILD_DIRPATH + "/plugins"
DATA_DIRPATH= "tmp/subnet-evm-start-node/"

def launch(plan, node_name, image):
    # Create launch node cmd
    NODE_DATA_DIR = DATA_DIR + "/" + node_name
    NODE_CONFIG_FILE_PATH = NODE_DATA_DIR + "/config.json"

	launch_node_cmd = [
		"./avalanchego",
		"--datadir=" + NODE_DATA_DIR,
		"--config-file=" + NODE_CONFIG_FILE_PATH,
	]

    # Create node config json
    node_config_template = read_file(static_files.NODE_CONFIG_JSON_FILEPATH)
    cfg_template_data = {
        "PluginDirPath": NODE_CONFIG_FILE_PATH
    }
    node_cfg_artifact = plan.render_templates(
        config= {
            "config.json" = struct(
                template = node_config_template,
                data = cfg_template_data,
            ),
        },
        name = "config-artifact"
    )

    subcommand_strs = [
        launch_node_cmd,
    ]
    command_str = " && ".join(subcommand_strs)

    node_config = ServiceConfig(
        image = image,
        ports = {
            "RPC": PortSpec(number = RPC_PORT_NUM, transport_protocol = "TCP")
        },
        files = {
            NODE_CONFIG_FILE_PATH: node_cfg_artifact,
        },
        cmd = command_str
    )

    node_service = plan.add_service(node_name, node_config)
