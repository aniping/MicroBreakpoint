import json


def dumps(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def loads(value, default=None):
    if value in (None, ""):
        return default
    return json.loads(value)
