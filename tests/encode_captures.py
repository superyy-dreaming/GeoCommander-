"""Encode real Godot HDR framebuffer captures as sRGB PNGs, without visual edits."""
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[1] / "artifacts"
report = json.loads((root / (sys.argv[1] if len(sys.argv) > 1 else "visual-report.json")).read_text())
for capture in report["captures"]:
    raw_path = root / (capture["name"] + ".pixels")
    encoding = capture["raw_encoding"]
    dtype = np.dtype("<f2" if encoding.endswith("H") else ("<f4" if encoding.endswith("F") else "u1"))
    channels = 4 if encoding.startswith("RGBA") else 3
    data = np.frombuffer(raw_path.read_bytes(), dtype=dtype).astype(np.float32)
    data = data.reshape(capture["image_height"], capture["image_width"], channels)
    if encoding.endswith("8"):
        data /= 255.0
    rgb = np.maximum(data[:, :, :3], 0.0)
    srgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1.0 / 2.4) - 0.055)
    data[:, :, :3] = srgb
    pixels = np.rint(np.clip(data, 0.0, 1.0) * 255.0).astype(np.uint8)
    Image.fromarray(pixels).save(root / (capture["name"] + ".png"))
    print(capture["name"], encoding, capture["image_width"], capture["image_height"])
