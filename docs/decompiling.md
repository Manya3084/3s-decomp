# Decompiling

Name functions in the retail disc, then check that the rebuilt load image still matches.

The anniversary debug ELF is a later section. It is password-gated, and its addresses are not retail addresses.

## Setup

Follow the [build guide](builde-guide.md). You need `THIRD_U.BIN.retail` from US disc **SLUS-20949 v1.02**, path `THIRD/THIRD_U.BIN`:

| | |
| --- | --- |
| Size | 4,021,936 bytes (`0x3D5EB0`) |
| SHA-256 | `b609c9ab16561696deeb05133f897f68959c8e1e5ea1998e5c212960f0b32a74` |
| SHA-1 | `956d55c010c9eea37f264ceeb4c8d860d4a7d4a2` |

```bash
sha256sum -c <<< 'b609c9ab16561696deeb05133f897f68959c8e1e5ea1998e5c212960f0b32a74  THIRD_U.BIN.retail'
make build-retail
```

Success prints `load image matches THIRD_U.BIN.retail (0x3d5c80 bytes)`. That check assembles the disc code. It does not compile the game from C with the compiler that wrote the disc.

The disc `.comment` is `MW MIPS C Compiler (2.4.1.01)`. The compiler downloaded by `make setup_tools` is `mwcps2-3.0b38-030307`, and its objects are stamped `MW MIPS C Compiler (3.0.0)`. A few small functions match that 3.0 compiler at `-O1`. The retail link stays assembly until a C body reproduces the disc instructions.

The retail ELF has an empty `.symtab` and no `.mdebug`, `.eh_frame`, or `.debug`. `bin/dtk dwarf dump THIRD_U.BIN.retail` fails with `Failed to locate .debug section`. File offset of a virtual address is `0x80 + (vaddr - 0x100000)`. Code runs through vaddr `0x373780`. GP from `.reginfo` is `0x4D77F0`.

## What a retail name is

Names live in `config/retail/symbols/funcs.txt`:

```
Name = 0x00ADDR; // type:func size:0xNN
```

`size` is the next real function boundary minus the start, including trailing padding nops. One internal `jr` can be a mid-function return. A new prologue after a complete epilogue is a new function, even when splat merged the two.

A name belongs in that file when the disc body matches C in this tree, instruction for instruction. These are enough:

- The function's own error string names it, and the body implements that check. `ADXF_ReadSj32`, `ADXF_Seek`, and `ADXF_SetReqRdSct` were named this way. The PS2 source for those three is `INCLUDE_ASM`.
- Real C in `src/anniversary/` matches the disc instructions. `ADXT_Init` and `ADXT_ExecFsSvr` were named this way.
- A byte-identical pair is named when a unique neighbor or a function-pointer immediate pins which copy is which. `ADXT_Init` passes `adxini_rnaerr_cbfn` and `adxini_lscerr_cbfn`.
- An empty C body that is `jr ra` / nop can be named when it sits between uniquely matched neighbors.
- A one-field getter or setter can be named when the disc body is that load or store, the offset is a field a surrounding matched function uses, and source order or a callsite of the address pins it. `ADXT_ConfigVsyncSvr` stores `adxt_vsync_svr_flag`.

These are not enough:

- The same address in `config/anniversary/symbols/`. Debug link order and debug sizes are hints. `remake_mvxy_PoGR`, `cal_dm_vital_gauge_hosei`, `Passive13_0163`, and `Passive13_0160` were wrong retail names copied from the debug map.
- One callsite.
- Source order, a prototype, or a magic constant on an `INCLUDE_ASM` slot whose body was not matched.
- A second symbol at an address that already has a name. Replace the old symbol in place.

Retail release builds omit debug prints and debug infinite loops (`Store_Sound_Code`, `BAD SE CODE`, `ERR_STOP`, `Debug_w` shortcuts, cache-miss loops). Those omissions are not mismatches. Do not paste anniversary `-O0,p -DDEBUG` C into the retail link.

## Changing a name

1. Disassemble the range:

```bash
bin/mipsel-linux-gnu-objdump -d -m mips:5900 \
  --start-address=0xADDR --stop-address=0xEND \
  THIRD_U.BIN.retail
```

2. Edit `config/retail/symbols/funcs.txt`. Do not edit `config/retail/undefined_funcs_auto.txt` or `config/retail/undefined_syms_auto.txt`. `make build-retail` regenerates them. `config/retail/symbols/overlap_funcs.txt` and `string_funcs.txt` are not yaml inputs.
3. Check the table, then rebuild:

```bash
.venv/bin/python3 -c '
import re, sys
rows=[]
for line in open("config/retail/symbols/funcs.txt"):
    m=re.match(r"(\S+) = (0x[0-9A-Fa-f]+); // type:func size:(0x[0-9A-Fa-f]+)", line)
    if m:
        rows.append((m.group(1), int(m.group(2),16), int(m.group(3),16)))
names={}; addrs={}; bad=dups_n=dups_a=over=0
order=sorted(rows, key=lambda r: r[1])
for i,(n,a,s) in enumerate(order):
    if s<=0 or a%4: bad+=1
    if n in names: dups_n+=1
    if a in addrs: dups_a+=1
    names[n]=a; addrs[a]=n
    if i and a < order[i-1][1]+order[i-1][2]: over+=1
print(len(rows), bad, dups_n, dups_a, over)
sys.exit(1 if bad or dups_n or dups_a or over else 0)
'
make build-retail
```

4. Commit `funcs.txt` and the regenerated auto files. Do not commit `asm/`, `build/`, `THIRD_U.BIN.retail`, `encrypted.bin`, or disc images.

`config/retail/sfiii.retail.yaml` reads `funcs.txt` only. Splat emits a `glabel` for each name there even when `undefined_funcs_auto.txt` omits an inner split. The image still matches.

## Retail variants and retail-only functions

Every function in the retail code range now has a name. A few of them do not follow the "matches C in this tree" rule. They are listed here so nobody mistakes them for matched bodies.

### Retail variants

These disc bodies are the function the name says. The position, callers, and most of the body agree with the C, but the disc version differs from `src/anniversary/`. The C needs to change before any of them can be called matched.

| Function | Address | Difference on the disc |
| --- | --- | --- |
| `emLevelRemake` | `0x1975C0` | Extra branch: when a flag is 1, Difficulty 6/7 changes `max` by `exd / 2`. |
| `Warning_Init` | `0x199C90` | Calls `load_it_use_any_key2` twice. |
| `effect_00_move` | `0x19ADB0` | Empty `jr ra`. Entry 0 of the effect move table at `0x47ABE0`. |
| `effect_66_init` | `0x1BA6C0` | Calls the retail-only `effect_66_setup` and does not call `get_my_trans_mode` itself. |
| `effect_B6_move` | `0x1CB800` | Empty `jr ra`. Entry `B6` of the effect move table at `0x47ADB0`. |
| `sea_write` | `0x1FDAA0` | Converts with `litodp` where the C uses `fptodp`. |
| `Menu_Init` | `0x220EC0` | Calls `Setup_BG_General`. |
| `toSelectGame` | `0x221740` | One more `FadeOut` call. |
| `Screen_Adjust` | `0x225EE0` | Calls `dspwhPack` twice. The C makes those calls in `Screen_Adjust_Sub`. |
| `Screen_Adjust_Sub` | `0x2262F0` | No `dspwhPack` calls. They moved up to `Screen_Adjust`. |
| `SSPutStr_Bigger` | `0x2FA820` | Calls `SSSetUVOffsetForScale` first. |
| `AcrMain` | `0x34F530` | Different init and frame calls, including `drawLateQuads`. |
| `save_slot_trans` | `0x36F950` | Calls `setButtonImageColor` and `dispButtonImageLate`, not `dispButtonImage2`. |
| `save_msg_trans` | `0x3701A0` | Drops the first `KnjLocate`/`KnjPuts`/`sprintf` block. |

### Retail-only functions

The debug ELF and this tree have no counterpart for these. The names describe what the disc body does.

| Function | Address | What it does |
| --- | --- | --- |
| `_crt0_head` | `0x100000` | The two register clears before the ELF entry `_start`. |
| `effect_66_setup` | `0x1BA7B0` | Work setup called by `effect_66_init`. |
| `clear_key_work` | `0x21A170` | `memset`s the `keyConvert` work and zeroes the pad switch words. Called from `njUserInit`. |
| `SSSetUVOffsetForScale` | `0x2FA680` | Sets the four UV inset floats that `SSPutStrTexInputB` reads: 0.02 at scale <= 1, else 0.1. |
| `setButtonImageColor` | `0x301A10` | Stores the colour that `dispButtonImage`, `dispButtonImage2`, and `dispButtonImageLate` read. |
| `dispButtonImageLate` | `0x301FE0` | `dispButtonImage` that queues its quad with `pushLateQuad`. |
| `dispBorderedBox` | `0x302290` | Two `njDrawPolygon2D` boxes, an outer and a 1-pixel inset. Used by `save_slot_trans`. |
| `clearLateQuads` | `0x34F880` | Empties the 4-entry late quad queue. |
| `pushLateQuad` | `0x34F8E0` | Copies an 84-byte quad and its texture handle into the queue. |
| `drawLateQuads` | `0x34FA20` | Draws each queued quad with `ps2SeqsRenderQuad_A2`, then clears the queue. Called from `AcrMain`. |
| `flPS2GetTextureContext` | `0x35F6B0` | Fills a `plContext` from a texture handle for the ppg code. |

## Anniversary debug ELF

`make split`, `make build`, `tools/m2ctx.py`, and `bin/dtk dwarf dump` need `THIRD_U.BIN`, SHA-1 `cf58495054c31ad852175c66e9ca04d5094f000e`. That file is about 18 MB and contains DWARF. The password is not in this repository. Do not rename `THIRD_U.BIN.retail` to `THIRD_U.BIN`.

If you already have that ELF:

```bash
make split
bin/dtk dwarf dump THIRD_U.BIN
make build -j
```

A match prints `Files match ✅`. `decomp.me` preset `Street Fighter III: 3rd Strike (Anniversary Collection)` is for that debug build. Its function list and the CRI progress notes on the parent repository use debug addresses. Copying one of those addresses onto the retail disc is how the wrong names above got in.

PS2 SDK and libgcc stay as assembly.
