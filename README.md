# 3S Decomp

A matching decompilation of Street Fighter III: 3rd Strike for PlayStation 2.

The binary this tree rebuilds is the US retail disc ELF, Street Fighter Anniversary Collection **SLUS-20949 v1.02**, file `THIRD/THIRD_U.BIN`. Save it as `THIRD_U.BIN.retail`. Do not commit it.

| | |
| --- | --- |
| Size | 4,021,936 bytes (`0x3D5EB0`) |
| SHA-256 | `b609c9ab16561696deeb05133f897f68959c8e1e5ea1998e5c212960f0b32a74` |
| SHA-1 | `956d55c010c9eea37f264ceeb4c8d860d4a7d4a2` |

`make build-retail` assembles the labeled disc code and checks the load image. A match prints `load image matches THIRD_U.BIN.retail (0x3d5c80 bytes)`.

## Progress

1908 functions are named in `config/retail/symbols/funcs.txt`. A name is added when the disc body matches C already in this tree. The anniversary debug ELF (`THIRD_U.BIN`, SHA-1 `cf58495054c31ad852175c66e9ca04d5094f000e`) is a different file. Its password is not in this repository, so `make split` and `make build` cannot match here.

The disc has no `.debug` section. `bin/dtk dwarf dump` does not work on `THIRD_U.BIN.retail`.

## Where to start

- [Build guide](docs/builde-guide.md) covers the retail file, the toolchain, and `make build-retail`.
- [Decompiling guide](docs/decompiling.md) covers how a retail function is named.
- [Coding guidelines](docs/coding-guidelines.md) cover C style once a body is being matched as source.

## Community

The parent project discusses this decomp on the Crowded Street Discord, in `3s-decomp`.

[![Join the Discord](https://dcbadge.limes.pink/api/server/https://discord.gg/wqs6BqYr8C)](https://discord.gg/wqs6BqYr8C)
