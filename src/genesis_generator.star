GO_IMG = "golang:alpine"

STAKING_KEYS_PATH = "/tmp/data/staking/node-{0}/staker.key"
STAKING_CERT_PATH = "/tmp/data/staking/node-{0}/staker.cert"
GENESIS_FILE = "/tmp/data/genesis.json"

def create_genesis(plan, network_id, num_nodes):

    genesis_generator = plan.upload_files(
        "github.com/kurtosis-tech/avalanche-package/genesis")

    plan.add_service(
        name="genesis",
        config=ServiceConfig(
            image = GO_IMG,
            entrypoint=["sleep", "99999"],
            files={
                "/tmp/genesis": genesis_generator
            }
        )
    )

    plan.exec(
        service_name="genesis",
        recipe=ExecRecipe(
            command=[
                "/bin/sh", "-c", "cd /tmp/genesis && go run main.go {0} {1}".format(network_id, num_nodes)]
        )
    )

    return {
        "genesis": GENESIS_FILE,
        "certs": [STAKING_CERT_PATH.format(index) for index in range(0, num_nodes)],
        "keys": [STAKING_KEYS_PATH.format(index) for index in range(0, num_nodes)],
    }
