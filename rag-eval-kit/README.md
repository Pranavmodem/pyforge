# RAG Eval Kit

Evaluate lexical retrieval against a fixed corpus and labeled queries. The
local ranker uses BM25 with deterministic document-ID tie breaks. The JSON
report includes ranked IDs, per-query results, macro Recall@k, and MRR@k.

```sh
python3 rag_eval.py examples/retrieval.json --k 2
python3 -m unittest discover -s tests -v
```

Use separate labels for evaluation. The report measures retrieval against
those labels. It does not score generated answers or call a model service.
