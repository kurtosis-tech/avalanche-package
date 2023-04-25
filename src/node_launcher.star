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
    
    launch_node_cmd = [
	    "./avalanchego",
		"--data-dir='/tmp/data/node1/'",
        "--http-host=0.0.0.0",
	]
    launch_node_cmd_str = " ".join(launch_node_cmd)

    # Create node config json
    node_cfg_template = read_file(static_files.NODE_CFG_JSON_FILEPATH)
    cfg_template_data = {
        "PluginDirPath":"/tmp/plugins/"
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
        entrypoint = ["/bin/sh", "-c"],
        cmd = [launch_node_cmd_str],
        files = {
            "/tmp/data/node1/": node_cfg_artifact
        },
    )

    node_service = plan.add_service(node_name, node_service_config)

    # wait for this node to be healthy
    plan.wait(
        service_name=node_service.name,
        recipe=PostHttpRequestRecipe(
            port_id="RPC",
            endpoint="/ext/health",
            content_type = "application/json",
            body="{ \"jsonrpc\":\"2.0\", \"id\" :1, \"method\" :\"health.health\"}"
        ),
        field="code",
        assertion="==",
        target_value=200,
        timeout="1m",
    )