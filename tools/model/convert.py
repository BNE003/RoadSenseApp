#!/usr/bin/env python3
"""Converts the pothole detector's PyTorch weights to the Core ML package the app bundles.

Build-time tool only: Ultralytics and coremltools are never app dependencies.

    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
    .venv/bin/python convert.py            # weights -> PotholeDetector.mlpackage + model.json

The output goes to RoadSense/RoadSense/Resources/Models/ unless --out is given.
"""

import argparse
import json
import shutil
from pathlib import Path

from ultralytics import YOLO

HERE = Path(__file__).resolve().parent
DEFAULT_OUT = HERE.parent.parent / "RoadSense" / "RoadSense" / "Resources" / "Models"

# Which app kind a class name stands for (lower case). The mapping lives here and in model.json, not
# in Swift. Classes missing from this table (e.g. "Other") are exported but ignored by the app.
KIND_BY_CLASS_NAME = {
    "pothole": "pothole",
    "potholes": "pothole",
    "longitudinal crack": "crack",
    "transverse crack": "crack",
    "alligator crack": "crack",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", type=Path, default=HERE / "best-3.pt")
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
        "source": args.weights.name,
        "inputSize": imgsz,
        "classes": [
            {"index": index, "name": model.names[index], "kind": KIND_BY_CLASS_NAME[model.names[index].lower()]}
            for index in sorted(model.names)
            if model.names[index].lower() in KIND_BY_CLASS_NAME
        ],
        "ultralyticsVersion": train_args.get("version") or model.ckpt.get("version"),
    }
    (args.out / "model.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Wrote {target} and model.json (input {imgsz}px)")


if __name__ == "__main__":
    main()
