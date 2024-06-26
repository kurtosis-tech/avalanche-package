RPC_PORT_NUM = 9650
RPC_PORT_ID = "rpc"
STAKING_PORT_NUM = 9651
STAKING_PORT_ID = "staking"

EXECUTABLE_PATH = "avalanchego"
ABS_DATA_DIRPATH = "/tmp/data/"
NODE_NAME_PREFIX = "node-"

NODE_ID_PATH = "/tmp/data/node-{0}/node_id.txt"
BUILDER_SERVICE_NAME = "builder"

ABS_PLUGIN_DIRPATH = "/avalanchego/build/plugins/"

PUBLIC_IP = "127.0.0.1"

utils = import_module("./utils.star")


def launch(plan, genesis, image, node_count, ephemeral_ports, min_cpu, min_memory, vmId, dont_start_subnets,
           custom_subnet_vm_path, custom_subnet_vm_url):
    bootstrap_ips = []
    bootstrap_ids = []
    nodes = []
    launch_commands = []

    services = {}
    plan.print("Creating all the avalanche containers paralllely")
    for index in range(0, node_count):
        node_name = NODE_NAME_PREFIX + str(index)

        node_data_dirpath = ABS_DATA_DIRPATH + node_name + "/"
        node_config_filepath = node_data_dirpath + "config.json"

        launch_node_cmd = [
            "nohup",
            "/avalanchego/build/" + EXECUTABLE_PATH,
            "--genesis-file=/tmp/data/genesis.json",
            "--data-dir=" + node_data_dirpath,
            "--config-file=" + node_config_filepath,
            "--http-host=0.0.0.0",
            "--staking-port=" + str(STAKING_PORT_NUM),
            "--http-port=" + str(RPC_PORT_NUM),
            "--log-dir=/tmp/",
            "--network-health-min-conn-peers=" + str(node_count - 1),
        ]

        plan.print("Creating node {0} with command {1}".format(node_name, launch_node_cmd))

        public_ports = {}
        if not ephemeral_ports:
            public_ports["rpc"] = PortSpec(number=RPC_PORT_NUM + index * 2, transport_protocol="TCP", wait=None)
            public_ports["staking"] = PortSpec(number=STAKING_PORT_NUM + index * 2, transport_protocol="TCP", wait=None)

        log_files = ["main.log", "C.log", "X.log", "P.log", "vm-factory.log"]
        log_files_cmds = ["touch /tmp/{0}".format(log_file) for log_file in log_files]
        log_file_cmd = " && ".join(log_files_cmds)

        if custom_subnet_vm_path:
            subnet_evm_plugin = plan.upload_files(custom_subnet_vm_path)
            # take only dir from custom_subnet_vm_path
            plan.print("subnet_evm_plugin: {0}".format(custom_subnet_vm_path))
            # Extract the directory part of the path
            last_slash_index = custom_subnet_vm_path.rfind('/')
            subnet_evm_plugin_dir = custom_subnet_vm_path[:last_slash_index]
            plan.print("subnet_evm_plugin_dir: {0}".format(subnet_evm_plugin_dir))
            node_files = {
                "/tmp/data": genesis,
                subnet_evm_plugin_dir: subnet_evm_plugin
            }
        elif custom_subnet_vm_url:
            node_files = {
                "/tmp/data": genesis
            }

        node_service_config = ServiceConfig(
            image=image,
            ports={
                "rpc": PortSpec(number=RPC_PORT_NUM, transport_protocol="TCP", wait=None),
                "staking": PortSpec(number=STAKING_PORT_NUM, transport_protocol="TCP", wait=None)
            },
            entrypoint=["/bin/sh", "-c", log_file_cmd + " && cd /tmp && tail -F *.log"],
            files=node_files,
            public_ports=public_ports,
            min_cpu=min_cpu,
            min_memory=min_memory,
        )

        services[node_name] = node_service_config
        launch_commands.append(launch_node_cmd)

    nodes = plan.add_services(services)

    for index in range(0, node_count):
        node_name = NODE_NAME_PREFIX + str(index)

        node = nodes[node_name]
        launch_node_cmd = launch_commands[index]

        if bootstrap_ips:
            launch_node_cmd.append("--bootstrap-ips={0}".format(",".join(bootstrap_ips)))
            launch_node_cmd.append("--bootstrap-ids={0}".format(",".join(bootstrap_ids)))

        if not dont_start_subnets:
            plan.exec(
                service_name=node_name,
                recipe=ExecRecipe(
                    command=["mkdir", "-p", ABS_PLUGIN_DIRPATH]
                )
            )
            if custom_subnet_vm_path:
                cp(plan, node_name, custom_subnet_vm_path, ABS_PLUGIN_DIRPATH + vmId)
            elif custom_subnet_vm_url:
                download_to_path_and_untar(plan, node_name, custom_subnet_vm_url, ABS_PLUGIN_DIRPATH + vmId)

        plan.exec(
            service_name=node_name,
            recipe=ExecRecipe(
                command=["/bin/sh", "-c", " ".join(launch_node_cmd) + " >/dev/null 2>&1 &"],
            )
        )

        bootstrap_ips.append("{0}:{1}".format(node.ip_address, STAKING_PORT_NUM))
        bootstrap_id_file = NODE_ID_PATH.format(index)
        bootstrap_id = utils.read_file_from_service(plan, BUILDER_SERVICE_NAME, bootstrap_id_file)
        bootstrap_ids.append(bootstrap_id)

    wait_for_health(plan, "node-" + str(node_count - 1))

    rpc_urls = ["http://{0}:{1}".format(node.ip_address, RPC_PORT_NUM) for _, node in nodes.items()]
    public_rpc_urls = []
    if not ephemeral_ports:
        public_rpc_urls = ["http://{0}:{1}".format(PUBLIC_IP, RPC_PORT_NUM + index * 2) for index, node in
                           enumerate(nodes)]

    return rpc_urls, public_rpc_urls, launch_commands


def restart_nodes(plan, num_nodes, launch_commands, subnetId, vmId):
    for index in range(0, num_nodes):
        node_name = NODE_NAME_PREFIX + str(index)
        launch_command = launch_commands[index]
        launch_command.append("--track-subnets={0}".format(subnetId))

        # have no ps or pkill; so this is a work around
        plan.exec(
            service_name=node_name,
            recipe=ExecRecipe(
                command=["/bin/sh", "-c",
                         """grep -l 'avalanchego' /proc/*/status | awk -F'/' '{print $3}' | while read -r pid; do kill -9 "$pid"; done"""]
            )
        )

        plan.exec(
            service_name=node_name,
            recipe=ExecRecipe(
                command=["/bin/sh", "-c", " ".join(launch_command) + " >/dev/null 2>&1 &"],
            )
        )

    wait_for_health(plan, "node-" + str(num_nodes - 1))


def wait_for_health(plan, node_name):
    response = plan.wait(
        service_name=node_name,
        recipe=PostHttpRequestRecipe(
            port_id=RPC_PORT_ID,
            endpoint="/ext/health",
            content_type="application/json",
            body="{ \"jsonrpc\":\"2.0\", \"id\" :1, \"method\" :\"health.health\"}",
            extract={
                "healthy": ".result.healthy",
            }
        ),
        field="extract.healthy",
        assertion="==",
        target_value=True,
        timeout="5m",
    )


def cp(plan, node_name, src, dest):
    plan.exec(
        service_name=node_name,
        recipe=ExecRecipe(
            command=["cp", src, dest]
        )
    )


def download_to_path_and_untar(plan, node_name, url, dest):
    # Install curl
    plan.exec(
        service_name=node_name,
        recipe=ExecRecipe(
            command=["/bin/sh", "-c",
                     "apt update --allow-insecure-repositories && apt-get install curl -y --allow-unauthenticated"]
        )
    )

    # Download the file
    download_path = "/static_files/subnet_vm.tar.gz"
    plan.print("Downloading {0} to {1}".format(url, download_path))
    plan.exec(
        service_name=node_name,
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "mkdir -p /static_files/ && curl -L {0} -o {1}".format(url, download_path)]
        )
    )

    # Untar the downloaded file
    plan.print("Untaring {0}".format(download_path))
    plan.exec(
        service_name=node_name,
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "mkdir -p /avalanchego/build/plugins && tar -zxvf {0} -C /static_files/".format(download_path)]
        )
    )

    # Move the extracted binary to the destination
    plan.print("Moving extracted binary to {0}".format(dest))
    plan.exec(
        service_name=node_name,
        recipe=ExecRecipe(
            command=["/bin/sh", "-c", "mv /static_files/subnet-evm {0}".format(dest)]
        )
    )