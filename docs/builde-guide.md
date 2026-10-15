# Builde guide

## Cloning

```bash
git clone --recurse-submodules https://github.com/crowded-street/3s-decomp
```

## Setting up the environment

### Linux

1. Enable i386 architecture support and install packages.

    ```bash
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y $(cat tools/requirements-debian.txt)
    ```

2. Install Python dependencies.

    ```bash
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r tools/requirements-python.txt
    ```

3. Download build tools.

    ```bash
    make setup_tools
    ```

### Arch Linux

`mipsel-linux-gnu-as` is not in the official repositories. `make setup_tools` downloads Debian's mipsel binutils into `bin/` when that command is missing. wibo and EE GCC 2.96 are i386 binaries, so multilib (`lib32-glibc`) has to be enabled. `gcc -m32` has to work: setup builds `bin/ee-forkwrap.so`, which EE GCC needs because glibc 2.41+ crashes inside `fork()` when the GCC 2.96 driver calls it.

```bash
sudo pacman -S --needed $(cat tools/requirements-arch.txt)
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements-python.txt
make setup_tools
```

`make` uses `.venv/bin/python3` when that directory exists.

### macOS

1. Use the provided Dockerfile.

    ```bash
    docker build --tag sfiii-build:latest --build-arg USER=$USER .
    docker run --rm -it -v $(pwd):/sfiii sfiii-build /bin/bash
    ```

2. Activate Python venv.

    ```bash
    source /tools/.venv/bin/activate
    ```

3. Download build tools.

    ```bash
    make setup_tools
    ```

## Building

1. Put the matched `THIRD_U.BIN` in the root folder. Its SHA1 is `cf58495054c31ad852175c66e9ca04d5094f000e`.

    That file is the debug ELF (about 18 MB, with DWARF). It used to be checked in as `encrypted.bin` and decrypted in CI with a private password. Commit `be9b9bc` removed both the ciphertext and the workflow.

    The retail US disc file is a different build. `THIRD/THIRD_U.BIN` from SLUS-20949 v1.02 is SHA1 `956d55c010c9eea37f264ceeb4c8d860d4a7d4a2`, 4,021,936 bytes, and has no DWARF. Keep that file as `THIRD_U.BIN.retail`. `make split` rejects it.

    `encrypted.bin` from git history (commit `afd91f6`, removed in `be9b9bc`) is that debug ELF, AES-256-CBC, OpenSSL salted. Decrypt it with the CI password, which is not in the repo:

    ```bash
    # password in the environment, or one line in .bin-password
    make decrypt
    ```

2. Run `splat`.

    ```bash
    make split
    ```

3. Build.

    ```bash
    make build -j
    ```

If everything's okay you'll see the message `Files match ✅`.

## Retail disc

`make split` and `make build` match the debug ELF above. The US disc file is a smaller optimized build. Keep it as `THIRD_U.BIN.retail` (SHA1 `956d55c010c9eea37f264ceeb4c8d860d4a7d4a2`).

```bash
make build-retail
```

That splits `config/retail/sfiii.retail.yaml`, assembles the code with the vendored mipsel binutils, links `build/retail/THIRD_U.BIN`, and checks the load image. Success prints `load image matches THIRD_U.BIN.retail`. The disc ELF has no DWARF, so `dtk dwarf dump` still needs the debug ELF.

The retail Xbox `sf33rd.xbe` is a Release build. Its debug path is `d:\ac_work\bloom_projects\StreetFighterAnniversaryCollection_20040826v00\sf33rd\Project\SF33rdACR for XBOX\Release\sf33rd.exe`, and the matching PDB is not on the disc. Assert paths in that XBE name `sf33rd/Source/Game/Game.c`, `netm.c`, `rebattle.c`, `sf33rd/AcrSDK/xbox/base/`, and `sf33rd/Source/XBOX/xlive/`. Those filename strings are not in the PS2 ELF, so they do not add PS2 addresses. Shader CVS metadata on the Xbox tree points at `kawamura@cvs13f0:/home/cvs/3`.

The US Dreamcast GD-ROM (`Street Fighter III - 3rd Strike (USA).chd`) is product `T1213N`, version `V1.001`, dated `20000908`. The volume id is `STREET_FIGHTER_3_3RD` and the boot file is `1ST_READ.BIN` (14,329,504 bytes at LBA 542003). That image is raw SH-4 and is already unscrambled; running the KallistiOS descramble on it wipes the startup code. The only source paths in it are PPP/TCP middleware: `custom\tcp_disp.c`, `custom\os.c`, `custom\main0.c`, `custom\pk_drv.c`, `custom\emb_misc.c`, `kernel\ppp.c`, `pppcon\pppapi.c`, `pppcon\pppcon.c`, and `tcppapi\tcppapi.c`. `2_DP.BIN` holds Dream Passport tutorial, mail, and the same PPP stack (`dream\tutorial\prtutor.c`, `srxapi.c`, `mailcore.c`). The disc has no `.MAP`, `.ELF`, or `.SYM`. Strings shared with the PS2 ELF are credits, UI text, and CRI names already listed in `config/retail/symbols/funcs.txt`. Applying the `tools/name_retail.py` rule to those shared strings (one copy in each binary, one C function, one `lui`/`addiu` reference) produced no new PS2 addresses.

Retail names past the debug-address overlap come from `tools/name_retail.py`. A C string names a function when it occurs once in the ELF, once in the anniversary sources, and one function materializes it with `lui` plus `addiu` or `ori`. Padded `\0` literals are matched up to the first NUL. Where `jr ra` is followed by a stack restore and a new stack frame, that frame is its own function, which is how `ADXF_GetFsizeSct`, `ADXF_GetFsizeByte`, `ADXF_GetNumReqSct`, and `ADXF_GetNumReadSct` were separated. `SSPutStr`, `mmHeapInitialize`, `ADXERR_CallErrFunc1`, and `cvFsError` are the one callee still missing from two or more already-named callers. The debug ELF is still password-gated. These names do not change `make build-retail`.

[spc970-dumper](https://github.com/spc970-dumper-union/spc970-dumper) is a PS2SDK homebrew that copies the SPC970 MechaCon mask ROM (CXP101064, CXP102064, or CXP103049) out to USB as `ROM.BIN`. That ROM is the drive controller. It does not contain `THIRD_U.BIN`, its symbols, or the anniversary password.

The disc `.comment` says `MW MIPS C Compiler (2.4.1.01)`. That same stamp is inside the 2.4 (2000-12-13), 3.0 (2001-11-26), 3.0.1 (2002-01-23), and 3.0.3 (2002-07-16) `mwccps2` builds. The toolchain used here is `mwcps2-3.0b38-030307`, and its objects are stamped `MW MIPS C Compiler (3.0.0)`, so it is not the compiler that wrote the disc. With that 3.0 build 38 compiler, `-O1` reproduces `IsSafeHeadChunk`, `IsSafeProgChunk`, `IsSafeSmplChunk`, `IsSafeVagiChunk`, `GetNumSplit`, and `GetPhdParam`: same instructions, with `lui`/`jal` still relocatable, and with the retail copies inserting a few extra nops so some branch targets stay aligned. `-O4,p` fills delay slots and does not match. `CalcPhdParam` is the function after `GetPhdParam`. It stores every `CSE_PHDP` field, clamps pan three times at -64 and 63, divides volume by 127 with the multiplier `0x81020409`, and returns 0. That division shape appears when `p` (optimize for speed) is on, and none of the builds above reproduced the whole function. `strncmp` at `0x355708` is the compare those checkers call: a zero length returns 0, a NUL stops the scan, and a mismatch returns the unsigned byte difference.
