"""Compile a declarative schema and normalize CSV rows without external state."""

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Optional

INTEGER = re.compile(r"[+-]?[0-9]+\Z")
KINDS = {"text", "integer", "decimal", "boolean"}
KEYS = {"name", "source", "kind", "required", "default", "minimum", "maximum"}


@dataclass(frozen=True)
class Field:
    name: str
    source: str
    kind: str
    required: bool
    default: Optional[str]
    minimum: Optional[Decimal]
    maximum: Optional[Decimal]


def compile_schema(spec):
    if not isinstance(spec, list) or not spec:
        raise ValueError("schema must be a nonempty field list")
    fields = []
    names = set()
    for entry in spec:
        if not isinstance(entry, dict) or entry.keys() - KEYS:
            raise ValueError("invalid field definition")
        name = entry.get("name")
        source = entry.get("source", name)
        kind = entry.get("kind", "text")
        required = entry.get("required", True)
        default = entry.get("default")
        if not all(isinstance(value, str) and value.strip() for value in (name, source)):
            raise ValueError("field name and source are required")
        if name in names or not isinstance(kind, str) or kind not in KINDS:
            raise ValueError("duplicate field or unsupported kind")
        if type(required) is not bool or (default is not None and not isinstance(default, str)):
            raise ValueError("invalid required flag or default")
        bounds = [entry.get("minimum"), entry.get("maximum")]
        if any(bound is not None for bound in bounds) and kind not in {"integer", "decimal"}:
            raise ValueError("bounds require a numeric field")
        minimum, maximum = [
            _decimal(str(bound)) if bound is not None else None for bound in bounds
        ]
        if minimum is not None and maximum is not None and minimum > maximum:
            raise ValueError("minimum exceeds maximum")
        field = Field(name, source, kind, required, default, minimum, maximum)
        if default is not None:
            _normalize(field, default)
        names.add(name)
        fields.append(field)
    return tuple(fields)


def _decimal(value):
    try:
        number = Decimal(value)
    except InvalidOperation as exc:
        raise ValueError("expected a number") from exc
    if not number.is_finite() or abs(number.adjusted()) > 100:
        raise ValueError("expected a finite number in the supported range")
    return number


def _normalize(field, raw):
    value = (raw or "").strip()
    if not value:
        if field.default is None:
            if field.required:
                raise ValueError("missing required field " + field.name)
            return ""
        value = field.default.strip()
        if not value and field.required:
            raise ValueError("missing required field " + field.name)

    if field.kind == "text":
        return value
    if field.kind == "boolean":
        token = value.casefold()
        if token in {"true", "1", "yes"}:
            return "true"
        if token in {"false", "0", "no"}:
            return "false"
        raise ValueError("invalid boolean for " + field.name)

    if field.kind == "integer" and not INTEGER.fullmatch(value):
        raise ValueError("invalid integer for " + field.name)
    number = _decimal(value)
    if (field.minimum is not None and number < field.minimum) or (
        field.maximum is not None and number > field.maximum
    ):
        raise ValueError("value outside bounds for " + field.name)
    if field.kind == "integer":
        return str(int(number))
    return format(number, "f")


def normalize(fields, row):
    return {field.name: _normalize(field, row.get(field.source)) for field in fields}


def transform(fields, source, target):
    reader = csv.DictReader(source, strict=True)
    header = reader.fieldnames or []
    if not header or len(header) != len(set(header)):
        raise ValueError("CSV header is missing or contains duplicate names")
    rows = []
    for row in reader:
        if None in row or any(value is None for value in row.values()):
            raise ValueError("wrong column count on line {}".format(reader.line_num))
        try:
            rows.append(normalize(fields, row))
        except ValueError as exc:
            raise ValueError("line {}: {}".format(reader.line_num, exc)) from exc
    writer = csv.DictWriter(target, fieldnames=[field.name for field in fields], lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema")
    parser.add_argument("input")
    args = parser.parse_args()
    try:
        with open(args.schema, encoding="utf-8") as source:
            fields = compile_schema(json.load(source))
        with open(args.input, encoding="utf-8-sig", newline="") as source:
            transform(fields, source, sys.stdout)
    except (OSError, ValueError, csv.Error) as exc:
        parser.exit(2, "pyforge: {}\n".format(exc))


if __name__ == "__main__":
    main()
