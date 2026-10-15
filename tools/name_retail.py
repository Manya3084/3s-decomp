#!/usr/bin/env python3
"""Name functions in the retail SLUS-20949 THIRD_U.BIN.

The debug ELF's symbol list is reused where an address is still a function
start. Unique string literals then name retail functions that reference them.
C string literals are cut at the first NUL so padded CRI messages match the
ELF. A `jr ra` / stack-restore / stack-alloc sequence splits functions that
splat merged, and the string is attached to that piece.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RETAIL = ROOT / "THIRD_U.BIN.retail"
FUNC_CSV = ROOT / "asm/retail/functions.csv"
SYM_DIR = ROOT / "config/anniversary/symbols"
OUT_DIR = ROOT / "config/retail/symbols"

LOAD_VADDR = 0x100000
LOAD_OFF = 0x80
CODE_END = 0x373780
MIN_STR = 6

SYM_RE = re.compile(
    r"^([A-Za-z_.$][\w.$]*)\s*=\s*(0x[0-9A-Fa-f]+)\s*;\s*(?://\s*(.*))?$"
)
FUNC_DEF_RE = re.compile(
    r"^[A-Za-z_][\w\s\*]*?\s+([A-Za-z_][\w]*)\s*\([^;]*\)\s*\{",
    re.M,
)
STR_RE = re.compile(r'"((?:\\.|[^"\\])*)"')


def load_functions() -> dict[int, int]:
    out: dict[int, int] = {}
    with FUNC_CSV.open() as handle:
        for row in csv.DictReader(handle):
            out[int(row["address"], 16)] = int(row["length"], 16)
    return out


def parse_symbols() -> list[tuple[str, int, str, str]]:
    found = []
    for path in sorted(SYM_DIR.glob("*.txt")):
        for line in path.read_text(errors="replace").splitlines():
            match = SYM_RE.match(line.strip())
            if not match:
                continue
            name, addr_s, comment = match.group(1), match.group(2), match.group(3) or ""
            if "ignore:true" in comment.replace(" ", ""):
                continue
            if "type:func" not in comment and not name.startswith("func_"):
                continue
            found.append((name, int(addr_s, 16), comment, path.name))
    return found


def c_string_owners() -> dict[str, set[str]]:
    owners: dict[str, set[str]] = {}
    for path in (ROOT / "src/anniversary").rglob("*.c"):
        text = path.read_text(errors="replace")
        current = None
        # Line-oriented so a string stays with the function that contains it.
        for line in text.splitlines():
            def_match = re.match(
                r"^(?:static\s+)?(?:inline\s+)?[\w\*][\w\s\*]+\s+([A-Za-z_][\w]*)\s*\([^;]*\)\s*\{?\s*$",
                line,
            )
            if def_match and "(" in line and not line.strip().endswith(";"):
                current = def_match.group(1)
            for raw in STR_RE.findall(line):
                try:
                    value = bytes(raw, "utf-8").decode("unicode_escape")
                except UnicodeDecodeError:
                    value = raw
                # CRI literals are often padded with \0 so the rodata word-aligns.
                # The bytes in the ELF stop at the first NUL.
                value = value.split("\x00", 1)[0].rstrip("\r\n\t")
                if len(value) < MIN_STR or current is None:
                    continue
                if not value.isascii() or any(ord(ch) < 32 for ch in value):
                    continue
                owners.setdefault(value, set()).add(current)
    return owners


def binary_strings(blob: bytes) -> list[tuple[int, str]]:
    found = []
    index = LOAD_OFF
    end = LOAD_OFF + 0x3D5C80
    while index < end:
        if 0x20 <= blob[index] < 0x7F:
            start = index
            while index < end and 0x20 <= blob[index] < 0x7F:
                index += 1
            if index < end and blob[index] == 0 and index - start >= MIN_STR:
                vaddr = LOAD_VADDR + (start - LOAD_OFF)
                found.append((vaddr, blob[start:index].decode("ascii")))
        index += 1
    return found


def references(blob: bytes, addresses: set[int]) -> dict[int, set[int]]:
    """Map a data address to function-body instruction vaddrs that materialize it."""
    code = blob[LOAD_OFF : LOAD_OFF + 0x3D5C80]
    words = [
        int.from_bytes(code[i : i + 4], "little") for i in range(0, len(code) - 3, 4)
    ]
    wanted = {}
    for addr in addresses:
        hi = (addr + 0x8000) >> 16
        lo = addr & 0xFFFF
        if lo >= 0x8000:
            lo -= 0x10000
        wanted.setdefault((hi & 0xFFFF, lo & 0xFFFF), set()).add(addr)

    hits: dict[int, set[int]] = {addr: set() for addr in addresses}
    for index, word in enumerate(words):
        if (word >> 26) != 0x0F:
            continue
        hi = word & 0xFFFF
        rt = (word >> 16) & 0x1F
        for follow in words[index + 1 : index + 6]:
            op = follow >> 26
            if op not in (0x09, 0x0D):  # addiu, ori
                continue
            if ((follow >> 21) & 0x1F) != rt:
                continue
            lo = follow & 0xFFFF
            if op == 0x09 and lo >= 0x8000:
                lo_key = lo - 0x10000
            else:
                lo_key = lo
            for addr in wanted.get((hi, lo_key & 0xFFFF), ()):
                hits[addr].add(LOAD_VADDR + index * 4)
    return hits


def inner_prologues(blob: bytes) -> list[int]:
    """Starts splat merged into the previous function.

    Retail MW code often ends with `jr ra` / `addiu sp, sp, +N` and the next
    function begins `addiu sp, sp, -N`. splat's analyzer keeps those as one
    function. The new start is only used to place a string on the right one.
    """
    code = blob[LOAD_OFF : LOAD_OFF + (CODE_END - LOAD_VADDR)]
    words = [
        int.from_bytes(code[i : i + 4], "little") for i in range(0, len(code) - 3, 4)
    ]
    found = []
    for index in range(len(words) - 3):
        if words[index] != 0x03E00008:
            continue
        restore, alloc = words[index + 1], words[index + 2]
        if (restore >> 16) != 0x27BD or (alloc >> 16) != 0x27BD:
            continue
        imm_restore, imm_alloc = restore & 0xFFFF, alloc & 0xFFFF
        if imm_restore == 0 or imm_restore >= 0x8000 or imm_alloc < 0x8000:
            continue
        found.append(LOAD_VADDR + (index + 2) * 4)
    return found


def function_at(functions: dict[int, int], vaddr: int) -> int | None:
    # Functions are dense enough for a linear scan of the sorted keys once.
    prev = None
    for start, length in functions.items():
        if start <= vaddr < start + max(length, 4):
            return start
        if start > vaddr:
            break
        prev = start
    return prev if prev is not None and vaddr < prev + functions[prev] + 0x20 else None


def main() -> None:
    functions = load_functions()
    ordered = dict(sorted(functions.items()))
    blob = RETAIL.read_bytes()

    overlap = []
    used_addr: dict[int, str] = {}
    for name, addr, comment, origin in parse_symbols():
        if addr not in ordered:
            continue
        if not (LOAD_VADDR <= addr < LOAD_VADDR + 0x3D5C80):
            continue
        if name.startswith("func_") or name.startswith("D_"):
            continue
        if addr in used_addr:
            continue
        used_addr[addr] = name
        size = ordered[addr]
        overlap.append(
            f"{name} = {addr:#010x}; // type:func size:{size:#x} from:{origin}"
        )

    owners = c_string_owners()
    strings = binary_strings(blob)
    unique_bin: dict[str, int] = {}
    seen: set[str] = set()
    dupes: set[str] = set()
    for vaddr, text in strings:
        if text in seen:
            dupes.add(text)
            unique_bin.pop(text, None)
        else:
            seen.add(text)
            unique_bin[text] = vaddr

    candidates = []
    for text, vaddr in unique_bin.items():
        funcs = owners.get(text)
        if not funcs or len(funcs) != 1:
            continue
        candidates.append((vaddr, next(iter(funcs)), text))

    # String homes use epilogue splits. Overlap names above stay on splat's starts.
    refined_starts = sorted(set(ordered) | set(inner_prologues(blob)))
    refined: dict[int, int] = {}
    for index, start in enumerate(refined_starts):
        nxt = refined_starts[index + 1] if index + 1 < len(refined_starts) else CODE_END
        if start < CODE_END:
            refined[start] = max(nxt - start, 4)
    refined = dict(sorted(refined.items()))

    refs = references(blob, {vaddr for vaddr, _, _ in candidates})
    named_from_strings = []
    for vaddr, func_name, text in candidates:
        sites = refs.get(vaddr, set())
        homes = {function_at(refined, site) for site in sites}
        homes.discard(None)
        if len(homes) != 1:
            continue
        home = next(iter(homes))
        if home in used_addr or home >= CODE_END:
            continue
        used_addr[home] = func_name
        named_from_strings.append(
            f"{func_name} = {home:#010x}; // type:func size:{refined[home]:#x} string:{text[:60]!r}"
        )

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "overlap_funcs.txt").write_text("\n".join(overlap) + "\n")
    (OUT_DIR / "string_funcs.txt").write_text("\n".join(named_from_strings) + "\n")
    print(f"retail functions: {len(ordered)}")
    print(f"named from debug addresses that still match: {len(overlap)}")
    print(f"named from a unique source string: {len(named_from_strings)}")
    print(f"still unnamed: {len(ordered) - len(used_addr)}")


if __name__ == "__main__":
    main()
