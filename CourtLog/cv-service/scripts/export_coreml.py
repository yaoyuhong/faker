#!/usr/bin/env python3
"""Export TrackNet PyTorch weights to Core ML for on-device inference (Phase 3).

Usage:
  python scripts/export_coreml.py --weights models/tracknet.pth --output models/TrackNet.mlpackage

Requires: torch, coremltools, and vendor TrackNet model definition.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert TrackNet to Core ML")
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("models/TrackNet.mlpackage"))
    args = parser.parse_args()

    if not args.weights.exists():
        raise SystemExit(f"Weights not found: {args.weights}")

    try:
        import coremltools as ct  # noqa: F401
        import torch
    except ImportError as e:
        raise SystemExit("Install torch and coremltools first") from e

    # TODO: import TrackNet architecture from vendor/tracknet
    # model = TrackNet()
    # model.load_state_dict(torch.load(args.weights, map_location="cpu"))
    # model.eval()
    # example = torch.randn(1, 9, 360, 640)  # 3 RGB frames stacked
    # traced = torch.jit.trace(model, example)
    # mlmodel = ct.convert(traced, inputs=[ct.TensorType(shape=example.shape)])
    # mlmodel.save(str(args.output))
    print(
        "Stub: wire TrackNet architecture from vendor/tracknet, then run conversion.\n"
        f"Target output: {args.output}"
    )


if __name__ == "__main__":
    main()
