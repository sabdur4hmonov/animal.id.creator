import math

import numpy as np

from biolivestock_research.dataset import Sample, validate_protocol
from biolivestock_research.embedding import normalize_vectors


def evaluate(samples: list[Sample], embeddings: np.ndarray, split: str, threshold: float) -> dict:
    if split not in ("validation", "test") or not math.isfinite(threshold) or not -1 <= threshold <= 1:
        raise ValueError("Select validation/test and a finite cosine threshold between -1 and 1")
    vectors = normalize_vectors(embeddings)
    if len(samples) != len(vectors):
        raise ValueError("Embedding/sample count mismatch")
    if len({sample.species for sample in samples}) != 1:
        raise ValueError("Cannot compare different species")
    validate_protocol(samples, samples[0].species)
    gallery = [i for i, sample in enumerate(samples) if sample.split == split and sample.role == "gallery"]
    query = [i for i, sample in enumerate(samples) if sample.split == split and sample.role == "query"]
    if not gallery or not query:
        raise ValueError("Selected split needs gallery and query samples")
    scores = np.clip(vectors[query] @ vectors[gallery].T, -1, 1)
    identities = [samples[i].animal_id for i in gallery]
    genuine_mask = np.array([[samples[i].animal_id == identity for identity in identities] for i in query])
    genuine, impostor = scores[genuine_mask], scores[~genuine_mask]
    rows = []
    for index, sample_index in enumerate(query):
        order = np.argsort(-scores[index], kind="stable")
        best = order[0]
        score = float(scores[index, best])
        # Equal best scores for different identities cannot support an identity decision.
        tied = {identities[i] for i in order if np.isclose(scores[index, i], score, atol=1e-6, rtol=0)}
        ambiguous = len(tied) > 1
        accepted = score >= threshold and not ambiguous
        expected = samples[sample_index].animal_id
        rows.append(
            {
                "sample_id": samples[sample_index].sample_id,
                "expected_animal_id": expected,
                "enrolled": expected in identities,
                "candidate_animal_id": identities[best] if not ambiguous else None,
                "cosine_score": score,
                "ambiguous": ambiguous,
                "accepted": accepted,
                "correct": accepted and identities[best] == expected,
            }
        )
    known = [row for row in rows if row["enrolled"]]
    unknown = [row for row in rows if not row["enrolled"]]
    return {
        "split": split,
        "threshold": threshold,
        "gallery_images": len(gallery),
        "gallery_animals": len(set(identities)),
        "known_queries": len(known),
        "unknown_queries": len(unknown),
        "known_query_failure_rate": sum(not row["correct"] for row in known) / len(known) if known else None,
        "unknown_query_acceptance_rate": sum(row["accepted"] for row in unknown) / len(unknown)
        if unknown
        else None,
        "known_wrong_accepts": sum(row["accepted"] and not row["correct"] for row in known),
        "genuine_pairs": int(genuine.size),
        "impostor_pairs": int(impostor.size),
        "genuine_pair_rejection_rate": float(np.mean(genuine < threshold)) if genuine.size else None,
        "impostor_pair_acceptance_rate": float(np.mean(impostor >= threshold)) if impostor.size else None,
        "queries": rows,
        "research_only": True,
    }
