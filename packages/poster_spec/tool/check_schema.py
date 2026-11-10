"""Check spec.schema.json against the shared fixtures (keeps Dart and Python in sync).

Usage: python packages/poster_spec/tool/check_schema.py packages/poster_spec
valid/ and invalid_semantic/ must pass the schema; invalid/ must fail it.
invalid_semantic/ is rejected only by the Dart validator / factory QA (cross-field rules).
"""
import json, sys, pathlib
from jsonschema import Draft202012Validator
root = pathlib.Path(sys.argv[1])
schema = json.loads((root / "schema/spec.schema.json").read_text(encoding="utf-8"))
Draft202012Validator.check_schema(schema)
v = Draft202012Validator(schema)
ok = True
for d, expect_valid in [("valid", True), ("invalid", False), ("invalid_semantic", True)]:
    for f in sorted((root / "test/fixtures" / d).glob("*.json")):
        valid = v.is_valid(json.loads(f.read_text(encoding="utf-8")))
        status = "OK " if valid == expect_valid else "BAD"
        ok &= valid == expect_valid
        print(f"{status} {d}/{f.name}: schema {'accepts' if valid else 'rejects'}")
sys.exit(0 if ok else 1)
