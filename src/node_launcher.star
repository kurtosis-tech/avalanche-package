static_files = import_module("github.com/kurtosis-tech/avalanche-package/static_files/static_files.star")

RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"

EXECUTABLE_PATH = "avalanchego"
ABS_PLUGIN_DIRPATH = "/avalanchego/build/plugins/"
ABS_DATA_DIRPATH= "/tmp/data/"

def launch(plan, node_name_prefix, image, node_count):
    # Create launch node cmd
    plan.print(node_count)

    bootstrap_ips = []
    bootstrap_ids = []
    output_services = []

    for index in range(0, node_count):        

        node_name = node_name_prefix + str(index)

        node_data_dirpath =  ABS_DATA_DIRPATH + node_name + "/"
        node_config_filepath = node_data_dirpath + "config.json"

        launch_node_cmd = [
            "./" + EXECUTABLE_PATH,
            "--data-dir=" + node_data_dirpath
    ,
            "--config-file=" + node_config_filepath,
            # TODO: add comment about why this is needed
            "--http-host=0.0.0.0",
        ]

        if bootstrap_ips:
            launch_node_cmd.append("--bootstrap-ips={0}".format(",".join(bootstrap_ips)))
            launch_node_cmd.append("--bootstrap-ids={0}".format(",".join(bootstrap_ids)))

        launch_node_cmd_str = " ".join(launch_node_cmd)

        # Create node config json
        node_cfg_template = read_file(static_files.NODE_CFG_JSON_FILEPATH)
        cfg_template_data = {
            "PluginDirPath": ABS_PLUGIN_DIRPATH,
        }
        node_cfg = plan.render_templates(
            config= {
                "config.json": struct(
                    template = node_cfg_template,
                    data = cfg_template_data,
                ),
            },
            name = "node-cfg-" + str(index)
        )

        node_service_config = ServiceConfig(
            image = image,
            ports = {
                "rpc": PortSpec(number = RPC_PORT_NUM, transport_protocol = "TCP")
            },
            entrypoint = ["/bin/sh", "-c"],
            cmd = [launch_node_cmd_str],
            files = {
                node_data_dirpath
        : node_cfg,
            },
        )

        node_service = plan.add_service(node_name, node_service_config)

        # wait for this node to be healthy
        response = plan.wait(
            service_name=node_service.name,
            recipe=PostHttpRequestRecipe(
                port_id="rpc",
                endpoint="/ext/info",
                content_type = "application/json",
                body="{ \"jsonrpc\":\"2.0\", \"id\" :1, \"method\" :\"info.getNodeID\"}",
                extract = {
                    "nodeID": ".result.nodeID",
                }
            ),
            field="code",
            assertion="==",
            target_value=200,
            timeout="1m",
        )

        bootstrap_ips.append("{0}:{1}".format(node_service.ip_address, RPC_PORT_NUM))
        bootstrap_ids.append(response["extract.nodeID"])
        output_services.append(node_service)

    return output_services