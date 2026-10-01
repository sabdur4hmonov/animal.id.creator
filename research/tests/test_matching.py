import numpy as np
import pytest

from biolivestock_research.matching import evaluate


@pytest.fixture
def vectors():
    return np.array([[1, 0], [0, 1], [1, 0], [-1, 0]], dtype=np.float32)


def test_known_and_unknown_query_metrics(samples, vectors):
    result = evaluate(samples, vectors, "test", 0.5)
    assert result["known_queries"] == result["unknown_queries"] == 1
    assert result["genuine_pairs"] == 1
    assert result["impostor_pairs"] == 3
    assert result["known_query_failure_rate"] == 0
    assert result["unknown_query_acceptance_rate"] == 0
    assert result["genuine_pair_rejection_rate"] == 0
    assert result["impostor_pair_acceptance_rate"] == 0


def test_wrong_known_identity_counts_as_failure_and_wrong_accept(samples, vectors):
    vectors[2] = [0, 1]
    result = evaluate(samples, vectors, "test", 0.5)
    assert result["known_query_failure_rate"] == 1
    assert result["known_wrong_accepts"] == 1


def test_tied_identities_are_ambiguous_and_rejected(samples, vectors):
    vectors[3] = [1, 1]
    result = evaluate(samples, vectors, "test", 0.5)
    row = result["queries"][1]
    assert row["ambiguous"] and not row["accepted"]
    assert row["candidate_animal_id"] is None


@pytest.mark.parametrize("threshold", [float("nan"), float("inf"), -1.1, 1.1])
def test_invalid_threshold_is_rejected(samples, vectors, threshold):
    with pytest.raises(ValueError, match="finite cosine threshold"):
        evaluate(samples, vectors, "test", threshold)


@pytest.mark.parametrize("bad", [[[0, 0]] * 4, [[float("nan"), 1]] * 4, [[float("inf"), 1]] * 4])
def test_invalid_vectors_are_rejected(samples, bad):
    with pytest.raises(ValueError):
        evaluate(samples, np.array(bad), "test", 0.5)


def test_missing_unknown_queries_reports_unavailable_metric(samples, vectors):
    result = evaluate(samples[:3], vectors[:3], "test", 0.5)
    assert result["unknown_queries"] == 0
    assert result["unknown_query_acceptance_rate"] is None
