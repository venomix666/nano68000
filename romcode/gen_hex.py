#!/usr/bin/env python3
import argparse
import struct
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Convert a big-endian 68k binary into 16-bit hex words for Verilator."
    )
    parser.add_argument("input_bin", type=Path, help="Input binary file (e.g., test.bin)")
    parser.add_argument("output_hex", type=Path, help="Output hex file (e.g., test.hex)")
    parser.add_argument(
        "--words",
        type=int,
        default=None,
        help="Optional total 16-bit word count to zero-pad output to (e.g., 4096)",
    )
    args = parser.parse_args()

    data = args.input_bin.read_bytes()
    if len(data) % 2 != 0:
        data += b"\x00"

    words = [word for (word,) in struct.iter_unpack(">H", data)]

    if args.words is not None:
        if len(words) > args.words:
            print(
                f"Error: binary has {len(words)} 16-bit words, exceeding --words {args.words}",
                file=sys.stderr,
            )
            return 1
        words.extend([0] * (args.words - len(words)))

    lines = [f"{word:04x}\n" for word in words]
    args.output_hex.write_text("".join(lines), encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
