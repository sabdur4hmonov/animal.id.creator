# Offline cattle embeddings and matching

The `research/` package implements a reproducible representation baseline, exact cosine comparisons and error reporting. It is separate from the capture API. There is no production identification endpoint, vector database, accepted biometric confidence, or trained cattle embedding model yet. The next empirical step needs reviewed cattle muzzle images with reliable identities and capture sessions.

## Decisions

Use frozen ImageNet ResNet18 `avgpool` features as a small CPU baseline: 512 dimensions, L2 normalization, mean/std from [TorchVision's model documentation](https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.resnet18.html). Features from [TorchVision's extraction API](https://docs.pytorch.org/vision/stable/feature_extraction.html) are a starting point for measurement, not cattle-specific biometric training. The input is padded to a square and resized rather than center-cropped, preserving the reviewed muzzle. This intentionally differs from the published ImageNet center-crop preprocessing and requires cattle-data evaluation.

The downloaded [official weights](https://download.pytorch.org/models/resnet18-f37072fd.pth) are held in ignored `models/cattle/research/`; SHA-256 is `f37072fd47e89c5e827621c5baffa7500819f7896bbacec160b1a16c560e07ec`. Loading uses `weights_only=True`, verifies the full hash, and never downloads implicitly. ImageNet classification accuracy is not cattle identity accuracy. Sheep's matching config has the same schema and remains disabled; no sheep weights are supplied. For a fresh checkout, explicitly download those free weights to the configured path before extraction; data/weights are not committed.

Use exact NumPy cosine search for the evaluation reference, with the best gallery image per candidate. Equal best scores across distinct identities are ambiguous and rejected. This is not a decision on a production vector-search service. Defer that selection until we have measured error rates, gallery size, latency and operational targets. Configs are in `research/species_configs/`; the shared backend Species enum is reused, and there are no species-specific processing branches. No production database schema changes were made.

## Dataset protocol

The manifest is a JSON list. Each entry contains `sample_id`, `species`, `animal_id`, `session_id`, `split` (`train`, `validation`, `test`), `role` (`train`, `gallery`, `query`), relative `image_path`, SHA-256 and `reviewed_muzzle: true`. Optional `farm_id` and `camera_id` preserve acquisition provenance. Use `research/templates/muzzle_annotations.csv` as a collection checklist, then serialize reviewed entries as JSON. Never mark pending originals reviewed automatically.

Animals are disjoint across train/validation/test; same-animal gallery and query images come from different acquisition sessions. Unknown query animals are absent from the gallery. The validator rejects duplicates, path escapes, changed image bytes, mixed species, unreviewed images and session/identity leakage. Animal IDs must refer to independent ground truth, not a prediction from the model being evaluated. Do not infer capture sessions from filenames unless the dataset publisher documents that convention.

Select candidate thresholds on validation data, freeze the threshold, and evaluate test data once. The CLI requires an explicit threshold and does not choose an operational acceptance policy. Its JSON reports genuine-pair rejection, impostor-pair acceptance, known-query failure (rejection or wrong identity), known wrong accepts, and unknown-query acceptance. Each rate includes denominator counts; absent cohorts produce null metrics. Pair rates and whole-gallery query rates answer different questions. Comparisons among pairs from shared animals are correlated, so these counts are not independent-trial confidence guarantees.

## Commands

Dataset validation and matching metrics use the existing Python environment without PyTorch:

```powershell
.\.venv\Scripts\python.exe tools/research.py validate --config research/species_configs/cattle.yaml --manifest data/research/manifest.json --dataset-root data/research/crops
.\.venv\Scripts\python.exe tools/research.py evaluate --config research/species_configs/cattle.yaml --artifact data/research/embeddings.npz --split test --threshold 0.8 --output data/research/test-report.json
.\.venv\Scripts\python.exe -m pytest -c research/pyproject.toml research/tests -q -p no:cacheprovider
```

`0.8` is an example argument, not a validated cutoff. Extraction needs CPU torch/torchvision, already available in the backend Docker image. From this repository's PowerShell terminal:

```powershell
$researchMount="type=bind,source=$PWD\research,target=/srv/research,readonly"
$toolsMount="type=bind,source=$PWD\tools,target=/srv/tools,readonly"
$modelsMount="type=bind,source=$PWD\models,target=/srv/models,readonly"
$dataMount="type=bind,source=$PWD\data,target=/srv/data"
docker run --rm --network none --mount $researchMount --mount $toolsMount --mount $modelsMount --mount $dataMount biolivestock-verification-api python /srv/tools/research.py extract --config /srv/research/species_configs/cattle.yaml --model-root /srv --manifest /srv/data/research/manifest.json --dataset-root /srv/data/research/crops --output /srv/data/research/embeddings.npz
```

Archives store normalized vectors, ordered sample metadata, a manifest fingerprint, and the complete model/preprocessing config. Evaluation refuses a changed configuration or fingerprint. Loading disables NumPy pickle support. Output creation refuses to overwrite existing evidence. A successful CPU smoke check on the licensed stock photograph produced 512-dimensional features and repeat cosine 1.0; it does not establish cattle recognition accuracy. Evidence: `data/research/resnet18-smoke.json`.

## Public dataset reconnaissance

- [Beef Cattle Muzzle/Noseprint database](https://zenodo.org/records/6324361), Xiong/Li/Erickson: publisher describes 4923 cleaned crops from 268 animals in identity folders. The visible record did not establish per-image session labels or a readable license, and the metadata API timed out during this session. Do not assume permission or invent session labels; confirm those prerequisites before importing/training. No large archive was downloaded.
- [ReCowGnition's author repository](https://github.com/marcohuber/recowgnition): access requires name/affiliation and permits non-commercial use. An access request or credentials requires Sardorbek; none were submitted.

No qualifying labeled multi-session dataset is currently present in this repository. Further empirical model selection/training and acceptance calibration are blocked on that data or an accessible dataset with clear rights and session provenance.
