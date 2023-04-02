node_launcher = import_module("github.com/kurtosis-tech/avalanche-package/src/node_launcher.star")
input_parser = import_module("github.com/kurtosis-tech/avalanche-package/package_io/input_parser.star")

def run(plan, args):
    args_with_right_defaults = input_parser.parse_input(args)
    node_launcher.launch(plan, args_with_right_defaults.node_name, args_with_right_defaults.image)



