# Config validation in Python

[config_check.py](config_check.py) checks a deployment-style config dictionary against a set
of rules. It returns a list of **every** rule that failed, not just the first one.

## The config

```python
config = {
    "name": "",
    "environment": "tt",
    "replicas": 3,
    "resources": {"cpu": 4, "memory": 2048},
}
```

## Rules

| Field | Rule | Error message |
|---|---|---|
| `name` | must not be empty | `Name is not set correctly` |
| `environment` | must be one of `prod`, `test`, `dev` | `Enviroment is missing` |
| `replicas` | must be greater than 2 | `Replicas should be more than 2` |
| `resources.cpu` | must be at least 4 | `cpu not right` |
| `resources.memory` | must be at least 2048 | `memory not right` |

For the sample config above, `check(config)` returns:

```python
['Name is not set correctly', 'Enviroment is missing']
```

`replicas` is 3, `cpu` is 4 and `memory` is 2048, so those three rules pass.

## Two versions of `check`

1. **if statements (the active version):** one `if` per rule, and each failure is appended to an
   `error` list. It's easy to read and easy to step through in a debugger.
2. **Rules table (in comments):** each rule is a `(failed, message)` tuple, and a list
   comprehension collects the messages of the failed rules. Adding a rule takes one line, and the
   rules can be read as data.

Both versions collect every failure instead of stopping at the first one, so whoever fixes the
config sees all the problems at once.
