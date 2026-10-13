"""Validate ordered 3D cross-sections without inventing or reordering measurements."""

import numpy as np


def orientation(a, b, c):
    ab, ac = b - a, c - a
    return float(ab[0] * ac[1] - ab[1] * ac[0])


def on_segment(a, b, c, epsilon):
    return bool(np.all(c >= np.minimum(a, b) - epsilon) and np.all(c <= np.maximum(a, b) + epsilon))


def intersects(a, b, c, d, epsilon):
    values = (orientation(a, b, c), orientation(a, b, d),
              orientation(c, d, a), orientation(c, d, b))
    o1, o2, o3, o4 = values
    if ((o1 > epsilon and o2 < -epsilon) or (o1 < -epsilon and o2 > epsilon)) and (
        (o3 > epsilon and o4 < -epsilon) or (o3 < -epsilon and o4 > epsilon)
    ):
        return True
    return any(abs(o) <= epsilon and on_segment(start, end, point, epsilon)
               for o, start, end, point in ((o1, a, b, c), (o2, a, b, d),
                                          (o3, c, d, a), (o4, c, d, b)))


def validate_contour(coordinates, config):
    centered = coordinates - coordinates.mean(axis=0)
    span = float(np.linalg.norm(centered, axis=1).max())
    epsilon = config.contour_geometric_epsilon_ratio
    if span <= 0:
        raise ValueError("Chest contour has no extent")
    normalized = centered / span
    _, singular, axes = np.linalg.svd(normalized, full_matrices=False)
    if singular[1] <= epsilon * singular[0]:
        raise ValueError("Chest contour cannot be a line")
    if np.abs(normalized @ axes[2]).max() > config.contour_max_planarity_error_ratio:
        raise ValueError("Chest contour is not a planar cross-section")
    projected = normalized @ axes[:2].T
    count = len(projected)
    for i, current in enumerate(projected):
        previous, following = projected[(i - 1) % count], projected[(i + 1) % count]
        if np.linalg.norm(current - following) <= epsilon:
            raise ValueError("Chest contour has indistinguishable projected points")
        if abs(orientation(previous, current, following)) <= epsilon and (
            np.dot(previous - current, following - current) > epsilon
        ):
            raise ValueError("Chest contour retraces an adjacent edge")
        for j in range(i + 1, count):
            if j == i + 1 or (i == 0 and j == count - 1):
                continue  # Adjacent edges meet at their shared vertex.
            if intersects(current, following, projected[j], projected[(j + 1) % count], epsilon):
                raise ValueError("Chest contour self-intersects or overlaps")
