#!/usr/bin/env python3
"""Compare a linked retail ELF's load image to THIRD_U.BIN.retail."""

from __future__ import annotations

import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile

ROOT = Path(__file__).resolve().parents[1]
RETAIL = ROOT / "THIRD_U.BIN.retail"
VADDR = 0x100000
FILESZ = 0x3D5C80
MEMSZ = 0x543700
ENTRY = 0x100008


def load_image(path: Path) -> tuple[int, bytes, int]:
    elf = ELFFile(path.open("rb"))
    image = bytearray(FILESZ)
    memsz = 0
    for seg in elf.iter_segments():
        if seg["p_type"] != "PT_LOAD":
            continue
        memsz = max(memsz, seg["p_vaddr"] + seg["p_memsz"] - VADDR)
        if seg["p_filesz"] == 0:
            continue
        off = seg["p_vaddr"] - VADDR
        data = seg.data()
        image[off : off + seg["p_filesz"]] = data[: seg["p_filesz"]]
    return elf.header.e_entry, bytes(image), memsz


def main() -> None:
    linked = Path(sys.argv[1])
    entry, image, memsz = load_image(linked)
    retail = RETAIL.read_bytes()[0x80 : 0x80 + FILESZ]
    print(f"entry {entry:#x} mem span {memsz:#x}")
    if entry != ENTRY:
        print(f"entry is {entry:#x}, disc entry is {ENTRY:#x}")
    if memsz != MEMSZ:
        print(f"memory span is {memsz:#x}, disc memsz is {MEMSZ:#x}")
    if image == retail:
        print(f"load image matches {RETAIL.name} ({FILESZ:#x} bytes)")
        return
    for index, (got, exp) in enumerate(zip(image, retail)):
        if got != exp:
            print(f"first mismatch at vaddr {VADDR + index:#x}: got {got:#04x} disc {exp:#04x}")
            break
    else:
        print(f"length got {len(image):#x} disc {len(retail):#x}")
    sys.exit(1)


if __name__ == "__main__":
    main()
