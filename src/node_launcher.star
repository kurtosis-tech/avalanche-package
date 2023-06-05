RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"
STAKING_PORT_NUM = 9651
STAKING_PORT_ID = "staking"

EXECUTABLE_PATH = "avalanchego"
ABS_DATA_DIRPATH= "/tmp/data/"
NODE_NAME_PREFIX = "node-"

def launch(plan, genesis, image, node_count, expose_9650_if_one_node):
    bootstrap_ips = []
    bootstrap_ids = []
    output_services = []

    nodes = {}

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

        nodes[node_name] = node_service_config

        bootstrap_ips.append("{0}:{1}".format(node_service.hostname, STAKING_PORT_NUM))
        bootstrap_ids.append(response["extract.nodeID"])

    services = plan.add_services(nodes)

    return services