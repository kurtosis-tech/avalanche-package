node_launcher = import_module("github.com/kurtosis-tech/avalanche-package/src/node_launcher.star")
input_parser = import_module("github.com/kurtosis-tech/avalanche-package/package_io/input_parser.star")

def run(plan, args):
    args_with_right_defaults = input_parser.parse_input(args)
    expose_9650_if_one_node = args.get("test_mode", True)
    node = node_launcher.launch(plan, args_with_right_defaults["node_name_prefix"], args_with_right_defaults["avalanchego_image"], args_with_right_defaults["node_count"], expose_9650_if_one_node)
    return node



