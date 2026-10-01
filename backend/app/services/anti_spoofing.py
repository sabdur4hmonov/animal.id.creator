"""Uncalibrated review signals only; never returns a genuine/liveness probability."""

import math
from datetime import UTC

import cv2
import numpy as np


def periodic_energy(gray: np.ndarray) -> float:
    height, width = gray.shape
    values = gray.astype(np.float64)
    if values.std() < 4:
        return 0.0
    window = np.outer(np.hanning(height), np.hanning(width))
    spectrum = np.abs(np.fft.fftshift(np.fft.fft2((values - values.mean()) * window))) ** 2
    fx, fy = np.meshgrid(np.fft.fftshift(np.fft.fftfreq(width)), np.fft.fftshift(np.fft.fftfreq(height)))
    radius = np.hypot(fx, fy)
    band = spectrum[(radius >= 0.05) & (radius <= 0.45)]
    total = float(band.sum())
    if total <= 0 or not np.isfinite(total):
        return 0.0
    count = min(8, band.size)
    return float(np.partition(band, -count)[-count:].sum() / total)


def reflection_area(image, config) -> float:
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    mask = (
        (hsv[:, :, 2] >= config.reflection_pixel_threshold)
        & (hsv[:, :, 1] <= config.reflection_max_saturation)
    ).astype(np.uint8)
    count, _, stats, _ = cv2.connectedComponentsWithStats(mask)
    return float(stats[1:, cv2.CC_STAT_AREA].max() / mask.size) if count > 1 else 0.0


def rectangle_area(gray, config) -> float:
    edges = cv2.Canny(gray, 80, 160)
    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    largest = 0.0
    for contour in contours:
        polygon = cv2.approxPolyDP(contour, 0.025 * cv2.arcLength(contour, True), True)
        area = float(cv2.contourArea(polygon) / gray.size)
        if (
            len(polygon) == 4
            and cv2.isContourConvex(polygon)
            and (config.rectangle_min_area_fraction <= area <= config.rectangle_max_area_fraction)
        ):
            largest = max(largest, area)
    return largest


def image_signals(image, config):
    if not config.enabled:
        return {"status": "disabled", "flags": []}
    height, width = image.shape[:2]
    factor = min(1, config.analysis_max_dimension / max(height, width))
    analysis = cv2.resize(
        image, (max(1, round(width * factor)), max(1, round(height * factor))), interpolation=cv2.INTER_AREA
    )
    gray = cv2.cvtColor(analysis, cv2.COLOR_BGR2GRAY)
    periodic, reflection, rectangle = (
        periodic_energy(gray),
        reflection_area(analysis, config),
        rectangle_area(gray, config),
    )
    flags = []
    if periodic >= config.periodic_peak_fraction:
        flags.append("periodic_texture_possible_moire")
    if reflection >= config.reflection_min_area_fraction:
        flags.append("specular_highlight_possible_reflection")
    if rectangle:
        flags.append("rectangle_possible_screen_or_paper")
    return {
        "status": "advisory_unvalidated",
        "flags": flags,
        "periodic_peak_fraction": periodic,
        "largest_reflection_fraction": reflection,
        "largest_rectangle_fraction": rectangle,
        "presentation_medium": "undetermined",
    }


def utc(value):
    # SQLite test datetimes have no timezone; PostgreSQL stores timezone-aware UTC.
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def ground_distance(a, b):
    lat1, lat2 = math.radians(a["latitude"]), math.radians(b["latitude"])
    delta_lat = lat2 - lat1
    delta_lon = math.radians(b["longitude"] - a["longitude"])
    haversine = math.sin(delta_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    return 6_371_000 * 2 * math.asin(math.sqrt(min(1, max(0, haversine))))


def metadata_signals(metadata, received_at, config, previous=None):
    flags, speed = [], None
    device = metadata.device_signals
    evidence = metadata.gps_evidence
    if device and device.is_rooted is True:
        flags.append("client_reports_rooted_device")
    if device and device.is_emulator is True:
        flags.append("client_reports_emulator")
    if evidence and evidence.is_mock is True:
        flags.append("client_reports_mock_location")
    delta = (utc(received_at) - utc(metadata.timestamp)).total_seconds()
    if delta < -config.future_tolerance_seconds:
        flags.append("capture_time_in_future")
    if delta > config.capture_max_age_seconds:
        flags.append("capture_time_stale")
    if metadata.gps is None:
        flags.append("location_missing")
    if evidence:
        if evidence.accuracy_m is not None and evidence.accuracy_m > config.gps_max_accuracy_m:
            flags.append("location_low_accuracy")
        if (
            evidence.observed_at
            and abs((utc(metadata.timestamp) - utc(evidence.observed_at)).total_seconds())
            > config.gps_max_age_seconds
        ):
            flags.append("location_time_mismatch")
    if previous and previous.gps and metadata.gps:
        elapsed = (utc(metadata.timestamp) - utc(previous.timestamp)).total_seconds()
        separation = ground_distance(previous.gps, metadata.gps.model_dump())
        if elapsed < 0:
            flags.append("capture_time_out_of_order")
        elif elapsed == 0:
            if separation > config.gps_max_accuracy_m:
                flags.append("location_jump_same_timestamp")
        else:
            speed = separation / elapsed
            if speed > config.gps_max_speed_mps:
                flags.append("implausible_location_speed")
    return {
        "flags": flags,
        "reported_device": device.model_dump() if device else None,
        "reported_gps_evidence": evidence.model_dump(mode="json") if evidence else None,
        "previous_capture_id": previous.id if previous else None,
        "derived_speed_mps": speed,
        "client_evidence_trusted": False,
        "hardware_attestation": "not_implemented",
    }


def scan_risk(image, metadata, received_at, config, previous=None):
    return {
        "image": image_signals(image, config),
        "metadata": metadata_signals(metadata, received_at, config, previous),
        "config_snapshot": config.model_dump(mode="json"),
        "liveness_verdict": "not_assessed",
        "real_world_accuracy_verified": False,
        "motion_breathing": "blocked_on_labeled_video_dataset",
    }
