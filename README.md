# Pyforge

A collection of local tools for Python data preparation, retrieval evaluation,
photo formatting, and document OCR.

| Tool | What it does |
|---|---|
| [Pyforge](pyforge/README.md) | Normalizes CSV fields using a declarative schema for types, defaults, and bounds. |
| [RAG Eval Kit](rag-eval-kit/README.md) | Scores a BM25 ranker against labeled queries and reports Recall@k and MRR@k. |
| [Passport Studio](passport-studio/README.md) | Crops, rotates, and exports images to specified dimensions on macOS. |
| [ScanFree](scanfree/README.md) | Converts page images to an ordered, searchable PDF with on-device OCR on macOS. |

## Try the Python tools

Run from the repository root.

```sh
(cd pyforge && python3 pyforge.py examples/schema.json examples/input.csv)
(cd rag-eval-kit && python3 rag_eval.py examples/retrieval.json --k 2)
```

The Python tools use the standard library. The two image tools are command-line
programs that build with Swift on macOS. Their guides include build, usage, and
smoke-test commands.

The [original Python basics notebook](python_commands.ipynb) is available at the
repository root.
