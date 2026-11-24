config = {
    "name": "",
    "environment": "tt",
    "replicas": 3,
    "resources": {
        "cpu": 4,
        "memory": 2048
    }

}


# def check(c):
#     r = c["resources"]
#     rules = [
#         (c["name"] == "",                              "Name is not set correctly"),
#         (c["environment"] not in ("prod", "test", "dev"), "Environment is missing"),
#         (c["replicas"] <= 2,                           "Replicas should be more than 2"),
#         (r["cpu"] < 4,                                 "cpu not right"),
#         (r["memory"] < 2048,                           "memory not right"),
#     ]
#     return [msg for failed, msg in rules if failed]

# print(check(config))

def check(config):
    error = []

    if config["name"] == "":
        error.append("Name is not set correctly")
    if config["environment"] not in ("prod", "test", "dev"):
        error.append("Enviroment is missing")
    if config["replicas"] <= 2:
        error.append("Replicas should be more than 2")
    if config["resources"]["cpu"] < 4:
        error.append("cpu not right")
    if config["resources"]["memory"] < 2048:
        error.append("memory not right")
    return error

# print(check(config))
