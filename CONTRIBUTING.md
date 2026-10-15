Before you begin:

- Follow the [build guide](docs/builde-guide.md). The file you need is retail `THIRD/THIRD_U.BIN` from US disc SLUS-20949 v1.02, saved as `THIRD_U.BIN.retail`. SHA-256 `b609c9ab16561696deeb05133f897f68959c8e1e5ea1998e5c212960f0b32a74`. Size 4,021,936 bytes.
- Read the [decompilation guide](docs/decompiling.md). A retail name is a disc body that matches C in this tree. A shared address with the anniversary debug map is not a retail name.
- Read the [coding guidelines](docs/coding-guidelines.md) when you change C.

Check the result with `make build-retail`. Success prints `load image matches THIRD_U.BIN.retail (0x3d5c80 bytes)`.

Do not commit `THIRD_U.BIN.retail`, `THIRD_U.BIN`, `encrypted.bin`, `.bin-password`, `asm/`, `build/`, or disc images. Do not guess `BIN_PASSWORD`. The anniversary debug ELF is not required to name retail functions.
