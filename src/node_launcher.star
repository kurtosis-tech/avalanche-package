static_files = import_module("github.com/kurtosis-tech/avalanche-package/static_files/static_files.star")

RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"

ENTRYPOINT_ARGS = ["bash", "-c"]

PLUGIN_DIRPATH = "plugins"
DATA_DIRPATH= "data"

def launch(plan, node_name, image):
    # Create launch node cmd
    EXECUTABLE_PATH = "avalanchego"
    NODE_DATA_DIRPATH =  DATA_DIRPATH + "/" + node_name
    NODE_CONFIG_FILE_PATH = "/" + NODE_DATA_DIRPATH + "/config.json"
    
    # init_datadir_cmd_str = "mkdir -p {0}/".format(NODE_DATA_DIRPATH)
    launch_node_cmd = [
	    "./" + EXECUTABLE_PATH,
		"--data-dir=/tmp/data/node1/,
		"--config-file=/tmp/data/node1/config.json",
	]
    launch_node_cmd_str = " ".join(launch_node_cmd)

    # Create node config json
    node_cfg_template = read_file(static_files.NODE_CFG_JSON_FILEPATH)
    cfg_template_data = {
        "PluginDirPath":"/tmp/plugins"
    }
    node_cfg_artifact = plan.render_templates(
        config= {
            "config.json": struct(
                template = node_cfg_template,
                data = cfg_template_data,
            ),
        },
        name = "node-cfg"
    )

    node_service_config = ServiceConfig(
        image = image,
        ports = {
            "RPC": PortSpec(number = RPC_PORT_NUM, transport_protocol = "TCP")
        },
        cmd = [
            # init_datadir_cmd_str, 
            launch_node_cmd_str],
        files = {
            "/tmp/data/node1/": node_cfg_artifact.uuid
        },
    )

    node_service = plan.add_service(node_name, node_service_config)
