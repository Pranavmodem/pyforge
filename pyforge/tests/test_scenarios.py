import io
import json
import unittest
from pathlib import Path

from pyforge import compile_schema, normalize, transform

CASES = Path(__file__).parent.parent / "fixtures"


class SchemaScenarioTests(unittest.TestCase):
    def test_field_contract(self):
        count = 0
        for file in sorted(CASES.glob("*.jsonl")):
            for line in file.read_text(encoding="utf-8").splitlines():
                case = json.loads(line)
                count += 1
                with self.subTest(case=case["id"]):
                    if "error" in case:
                        with self.assertRaisesRegex(ValueError, case["error"]):
                            normalize(compile_schema(case["schema"]), case["row"])
                    else:
                        result = normalize(compile_schema(case["schema"]), case["row"])
                        self.assertEqual(result, case["expected"])
        self.assertGreater(count, 0)

    def test_invalid_row_leaves_output_empty(self):
        fields = compile_schema([{"name": "qty", "kind": "integer"}])
        target = io.StringIO()
        with self.assertRaisesRegex(ValueError, "line 3"):
            transform(fields, io.StringIO("qty\n04\nbad\n"), target)
        self.assertEqual(target.getvalue(), "")
