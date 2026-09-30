# BioLivestock AI roadmap

## Phase 1 — Data collection MVP
Build cattle-only camera capture, local first-pass image quality feedback, server-side blur and lighting checks, a species-aware YOLOv8n muzzle detector and crop pipeline, and structured image collection. Store images on the local filesystem with PostgreSQL metadata and Alembic migrations. Until a trained cattle muzzle checkpoint exists, collect quality-approved originals explicitly marked pending cropping. Establish a labeled dataset and calibrate quality thresholds with real farm photographs.

## Phase 2 — Cattle embeddings and matching
Use the curated cattle dataset to evaluate biometric representations, implement embeddings and matching, and select a vector search strategy only after measurable accuracy and error targets are defined. Keep training and evaluation animals separate, evaluate repeated captures across sessions, and report false matches and missed matches before treating a biometric result as identity evidence.

## Phase 3 — Liveness and anti-spoofing
Collect and label genuine and presentation-attack samples, define a threat model, and evaluate liveness signals under field conditions. Add capture guidance and anti-spoofing checks only when their measured reliability and operational tradeoffs are understood.

## Phase 4 — Weight and valuation
Investigate weight estimation using reference measurements and suitable images, then develop valuation features from validated weight estimates and independently sourced market inputs. Express uncertainty clearly and validate performance across breeds, ages, environments and collection devices before introducing B2B workflows.

## Phase 5 — Sheep and pilot
Collect a dedicated sheep dataset, add a sheep muzzle checkpoint and calibrated species configuration, enable the existing sheep entry, and run a limited pilot for both species. Evaluate usability, throughput, capture quality and downstream performance in real farms before expanding deployment.
