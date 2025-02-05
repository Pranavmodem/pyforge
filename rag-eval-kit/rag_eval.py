"""Rank a fixed corpus locally and report Recall@k and MRR@k."""

import argparse
import json
import math
import re
from collections import Counter

WORDS = re.compile(r"[^\W_]+", re.UNICODE)


def tokens(text):
    return WORDS.findall(text.casefold())


def rank(corpus, text):
    counts = {key: Counter(tokens(body)) for key, body in corpus.items()}
    sizes = {key: sum(words.values()) for key, words in counts.items()}
    average = sum(sizes.values()) / len(sizes) or 1
    scores = dict.fromkeys(corpus, 0.0)
    for term in sorted(set(tokens(text))):
        df = sum(term in terms for terms in counts.values())
        weight = math.log1p((len(counts) - df + 0.5) / (df + 0.5))
        for key, terms in counts.items():
            frequency = terms[term]
            norm = 1.2 * (0.25 + 0.75 * sizes[key] / average)
            scores[key] += weight * frequency * 2.2 / (frequency + norm)
    return sorted((key for key in scores if scores[key] > 0), key=lambda key: (-scores[key], key))


def evaluate(corpus, queries, k):
    if not isinstance(corpus, dict) or not corpus or any(
        not isinstance(key, str) or not key or not isinstance(body, str)
        for key, body in corpus.items()
    ):
        raise ValueError("corpus must map document IDs to text")
    if not isinstance(queries, list) or not queries or type(k) is not int or k < 1:
        raise ValueError("evaluation requires queries and a positive k")
    rows = []
    for query in queries:
        if not isinstance(query, dict) or not isinstance(query.get("text"), str):
            raise ValueError("query text is required")
        relevant = query.get("relevant")
        if not isinstance(relevant, list) or not relevant or any(
            not isinstance(key, str) or key not in corpus for key in relevant
        ) or len(set(relevant)) != len(relevant):
            raise ValueError("relevance labels must be unique corpus IDs")
        actual = rank(corpus, query["text"])[:k]
        hits = [position for position, key in enumerate(actual, start=1) if key in relevant]
        rows.append({
            "query": query["text"], "retrieved": actual,
            "recall": len(hits) / len(relevant), "reciprocal_rank": 1 / hits[0] if hits else 0.0,
        })
    return {
        "k": k, "recall": sum(row["recall"] for row in rows) / len(rows),
        "mrr": sum(row["reciprocal_rank"] for row in rows) / len(rows), "queries": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture")
    parser.add_argument("--k", type=int, default=3)
    args = parser.parse_args()
    try:
        with open(args.fixture, encoding="utf-8") as source:
            fixture = json.load(source)
        if not isinstance(fixture, dict):
            raise ValueError("fixture must be an object")
        report = evaluate(fixture.get("corpus"), fixture.get("queries"), args.k)
        print(json.dumps(report, indent=2, sort_keys=True))
    except (OSError, ValueError) as exc:
        parser.exit(2, "rag-eval: {}\n".format(exc))


if __name__ == "__main__":
    main()
