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
