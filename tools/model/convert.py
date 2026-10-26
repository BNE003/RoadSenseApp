#!/usr/bin/env python3
"""Converts best.pt (peterhdd/pothole-detection-yolov8) to the Core ML package the app bundles.

Build-time tool only: Ultralytics and coremltools are never app dependencies.

    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python convert.py            # best.pt -> PotholeDetector.mlpackage + model.json

The output goes to RoadSense/RoadSense/Resources/Models/ unless --out is given.
"""

import argparse
import json
import shutil
from pathlib import Path

from ultralytics import YOLO

HERE = Path(__file__).resolve().parent
DEFAULT_OUT = HERE.parent.parent / "RoadSense" / "RoadSense" / "Resources" / "Models"

# The checkpoint names its only class "0". The app's kind comes from the class index, so the
# mapping lives here and in model.json, not in Swift.
CLASS_KINDS = {0: "pothole"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", type=Path, default=HERE / "best.pt")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    model = YOLO(str(args.weights))
    train_args = model.ckpt.get("train_args", {})
    imgsz = int(train_args.get("imgsz", 640))

    exported = Path(model.export(format="coreml", imgsz=imgsz, half=True, nms=True))

    args.out.mkdir(parents=True, exist_ok=True)
    target = args.out / "PotholeDetector.mlpackage"
    if target.exists():
        shutil.rmtree(target)
    shutil.move(str(exported), target)

    metadata = {
        "name": "PotholeDetector",
        "source": "peterhdd/pothole-detection-yolov8",
        "inputSize": imgsz,
        "classes": [
            {"index": index, "name": model.names[index], "kind": CLASS_KINDS[index]}
            for index in sorted(model.names)
        ],
        "ultralyticsVersion": train_args.get("version") or model.ckpt.get("version"),
    }
    (args.out / "model.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Wrote {target} and model.json (input {imgsz}px)")


if __name__ == "__main__":
    main()
