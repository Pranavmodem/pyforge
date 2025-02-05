import unittest

from rag_eval import evaluate, rank


class RetrievalTests(unittest.TestCase):
    def test_ties_are_resolved_by_document_id(self):
        self.assertEqual(rank({"b": "pear", "a": "pear"}, "pear"), ["a", "b"])

    def test_known_recall_and_reciprocal_rank(self):
        report = evaluate(
            {"a": "pear", "b": "pear", "c": "plum"},
            [{"text": "pear", "relevant": ["b", "c"]}, {"text": "unmatched", "relevant": ["a"]}], 2,
        )
        self.assertEqual(report["recall"], 0.25)
        self.assertEqual(report["mrr"], 0.25)
        self.assertEqual(report["queries"][1]["retrieved"], [])

    def test_rejects_out_of_corpus_label(self):
        with self.assertRaisesRegex(ValueError, "corpus IDs"):
            evaluate({"a": "pear"}, [{"text": "pear", "relevant": ["b"]}], 1)
