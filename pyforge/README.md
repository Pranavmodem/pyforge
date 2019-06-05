# Pyforge

Pyforge normalizes CSV input using a declarative JSON field schema.

```sh
python3 pyforge.py examples/schema.json examples/input.csv
python3 -m unittest discover -s tests -v
```

A field names its output column and optionally its source column. Supported
kinds are text, integer, decimal, and boolean. Required fields can specify a
default. Numeric fields can constrain the minimum and maximum. The CLI
validates the whole file before writing output, so it is suited to inputs that
fit in memory. It does not execute expressions from configuration.

The regression corpus covers for source names, types,
defaults, required fields, ranges, Unicode, and malformed values. Only the
Python standard library is required.
