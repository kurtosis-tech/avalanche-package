# reads the given file in service without the new line
def read_file_from_service(plan, service_name, filename):
    output = plan.exec(
        service_name = service_name,
        recipe = ExecRecipe(
            command = ["/bin/sh", "-c", "cat {}".format(filename)]
        )
    )
    return output["output"]
