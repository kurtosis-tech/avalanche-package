RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"
STAKING_PORT_NUM = 9651
STAKING_PORT_ID = "staking"

EXECUTABLE_PATH = "avalanchego"
ABS_DATA_DIRPATH= "/tmp/data/"
NODE_NAME_PREFIX = "node-"

NODE_ID_PATH = "/tmp/data/node-{0}/node_id.txt"
GENESIS_SERVICE_NAME = "genesis"

def launch(plan, genesis, image, node_count, expose_9650_if_one_node):
    bootstrap_ips = []
    bootstrap_ids = []
    nodes = []

    for index in range(0, node_count):        

        node_name = NODE_NAME_PREFIX + str(index)

        node_data_dirpath =  ABS_DATA_DIRPATH + node_name + "/"
        node_config_filepath = node_data_dirpath + "config.json"

        launch_node_cmd = [
            "./" + EXECUTABLE_PATH,
            "--genesis=/tmp/data/genesis.json", 
            "--data-dir=" + node_data_dirpath,
            "--config-file=" + node_config_filepath,
            "--http-host=0.0.0.0",
            "--staking-port=" + str(STAKING_PORT_NUM),
            "--http-port="+ str(RPC_PORT_NUM),
        ]

        if bootstrap_ips:
            launch_node_cmd.append("--bootstrap-ips={0}".format(",".join(bootstrap_ips)))
            launch_node_cmd.append("--bootstrap-ids={0}".format(",".join(bootstrap_ids)))

        launch_node_cmd_str = " ".join(launch_node_cmd)

        public_ports = {}
        if expose_9650_if_one_node:
            public_ports["rpc"] = PortSpec(number = RPC_PORT_NUM+ index*2 , transport_protocol = "TCP")
            public_ports["staking"] = PortSpec(number = STAKING_PORT_NUM + index*2 , transport_protocol = "TCP")

        node_service_config = ServiceConfig(
            image = image,
            ports = {
                "rpc": PortSpec(number = RPC_PORT_NUM, transport_protocol = "TCP"),
                "staking": PortSpec(number = STAKING_PORT_NUM, transport_protocol = "TCP")
            },
            entrypoint = ["/bin/sh", "-c"],
            cmd = [launch_node_cmd_str],
            files = {
                "/tmp/": genesis,
            },
            public_ports = public_ports,
        )

        node = plan.add_service(
            name = node_name,
            config = node_service_config,
        )

        bootstrap_ips.append("{0}:{1}".format(node.ip_address, STAKING_PORT_NUM))
        bootstrap_id_file = NODE_ID_PATH.format(index)
        bootstrap_id = read_file_from_service(plan, GENESIS_SERVICE_NAME, bootstrap_id_file)
        bootstrap_ids.append(bootstrap_id)

        nodes.append(node)

    rpc_urls = ["http://{0}:{1}".format(node.ip_address, RPC_PORT_NUM) for node in nodes]

    return rpc_urls


# reads the given file in service without the new line
def read_file_from_service(plan, service_name, filename):
    output = plan.exec(
        service_name = service_name,
        recipe = ExecRecipe(
            command = ["/bin/sh", "-c", "cat {}".format(filename)]
        )
    )
    return output["output"]
