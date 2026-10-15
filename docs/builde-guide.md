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

The CapSndEng calls continue in address order after `CalcPhdParam`. `0x10000000` through `0x10000009` are the sound-driver command words, and they name `StartSound`, `mlSeKeyoff`, `mlSeStop`, `mlSeStopAll`, `mlSeSetLfo`, `mlSysSetMono`, and `mlSysSetBankVolume`. `PlaySe` is the only caller of `GetNumSplit`, `GetPhdParam`, and `CalcPhdParam`. `flSifRpcInit` binds the three SIF servers `0x01234567`, `0x09876543`, and `0x77755500`. `flSifRpcSend` is the switch on commands `0x309`, `1`, `2`, `3`, and `0x63`. `memset` and `memcpy` are the quadword memory routines those functions call. A shared address with the debug map is not a retail name: `remake_mvxy_PoGR` was sitting on `0x370E20` because that address is also a function start in the debug ELF, and the retail bytes there are `flSifRpcInit`.

[3sx](https://github.com/crowded-street/3sx) is a native port of this decomp. It ships the same `sf33rd` C under rearranged paths and has no symbol map, no ELF, and no anniversary password. Names that exist only in the port, such as the netplay menu, the glyph renderer, and the `effect_ng*` splits, are not retail addresses. The CapSndEng and `Sound3rd.c` sources are shared, and those bodies are what the disc matches.

`cseInitSndDrv` at `0x371490` calls `flSifRpcInit`, `mlRpcQueueInit`, `mlSeInitSndDrv`, and `mlTsbInit`, then writes `InitializeFlag`, `Counter`, and sixteen `SpuBankId` entries of `-1` at `gp+2608`. `cseExecServer` calls `mlTsbExecServer` and `mlRpcQueueSend` only when that flag is 1. `cseTsbRequest` adds the varargs into `rtpc[10]` and calls `mlTsbRequest`. `cseCheckVTransStatus` sends command `2` with result word `0x20000000` and ORs `1`, `0x10`, `0x100`, and `0x1000` from the reply. Its default path prints `[C.S.E] Unknown parameter in cseCheckVtransStatus().`. `cseSendBd2SpuWithId` is the `0x30000000` queue write, and `cseGetIdStoredBd` reads `SpuBankId[bank & 0xF]`.

`mlTsbInit` starts the TSB block at `0x372890`. `mlTsbGetDataAdrs` steps `SoundEvent` by `0x20`. `mlTsbRequest` switches on command bytes `1`, `2`, `3`, `5`, `6`, and `7` into `mlTsbKeyOn`, `mlSeKeyoff`, `mlSeStop`, `mlSeSetLfo`, `mlTsbCreateEcho`, and `mlTsbStopEcho`, then follows `link` until `0xFFFF`. The echo work is sixteen `CSE_ECHOWORK` slots of `0x38` bytes. `cal_dm_vital_gauge_hosei` was the debug-map name on `0x372960`. Those bytes test `SoundEvent.flags` bit 1 and call `PlaySe`, so the function is `mlTsbKeyOn`. `Passive13_0163` was the same kind of miss on `0x30E540`: that body returns 1 when `bgm_exe.kind` is 5 and 2 when `adx_now_playing` is set, which is `bgm_play_status`.

`Sound3rd.c` follows source order from `0x30D540`: `spu_all_off`, `cseSeStopAll`, `sound_bgm_off`, `setSeVolume`, `cseSysSetMasterVolume`, `setupSoundMode`, `cseSysSetMono`, and `sound_request_for_dc`. `setSeVolume` scales by `127/15`, the float word `0x41077777`. `adx_now_playing` accepts status `3` and `4` (`ADXT_STAT_PLAYING`, `ADXT_STAT_DECEND`). `adx_now_playend` accepts status `5`. `bgm_play_status` returns `1` when `bgm_exe.kind` is `5` and `2` when a track is playing. `SsBgmOff` stores `ptix` `0x7F` and `bank` `1`, then calls `sound_request_for_dc`. `cseTsbSetBankAddr` and `cseMemMapSetPhdAddr` are the pass-through calls at `0x17F6F0` and `0x17F710`.

`Sound3rd.c` continues on both sides of that block. `sndCheckVTransStatus` at `0x30D280` returns 1 when `cseCheckVTransStatus` is non-negative for types 0 and 1. `sndInitialLoad` calls `cseMemMapInit`, then the two pass-throughs with bank 0, then `load_any_color(109, 20)` at `0x17F730`. `checkAdxFileLoaded` picks file 89 or 90 from `bgm_type` and will not return until `load_it_use_any_key` yields a key. `Exit_sound_system` clears init bits 2 and 1 after `ADXT_Destroy` and `spu_all_off`. `Init_bgm_work` zeroes 22 bytes at `bgm_exe` and 8 bytes at `bgm_req`. `BGM_Server` is the `0xA40` function at `0x30D870`: it returns immediately unless init bit 2 is set, then copies `bgm_req` into `bgm_exe` when `req` is set. `bgm_volume_setup` adds the fade index to the mix, divides by 3 with multiplier `0x55555556` when `Country` is 1 and half-volume is on, and calls `ADXT_SetOutVol`. `Passive13_0160` was the debug-map name on that address. `SsRequest`, `SsRequest_CC` (bank 9), and `Standby_BGM` (bank 2) all go through `remake_sound_code_for_DC`, which subtracts `0x600` above code `0x760` and `0x300` above `0x400`. `Go_BGM` uses bank 3, `SsBgmFadeOut` bank 5, and `SsBgmFadeIn` bank 6, each with `ptix` `0x7F` and a fade of `0x8000` divided by the time. `SE_cursor_move`, `SE_selected`, `SE_dir_cursor_move`, and `SE_dir_selected` are `SsRequest` of 96, 98, 343, and 98. `ADXT_Finish` at `0x338E08` decrements the init count and, on zero, runs the library finish chain and stores `dtx_send_sw` back to 1. The retail copies omit `Store_Sound_Code` and the `BAD SE CODE` loop.

`spgauge_cont_init` at `0x30EC50` walks two `SPG_DAT` slots of `0x34` bytes, copies `store_max` and `gauge_len` from `SA_WORK` (`0x2C` bytes), and stores player colors `17` and `145`. `spgauge_cont_demo_init` fills both gauges, calls `sa_moji_trans`, and stores `col` as `1`. `spgauge_cont_main` calls `spgauge_control` for a side whose `gauge_stop_flag` is clear. `sag_bug_fix` zeroes `max`, `max_old`, and `max_rno`. `wipe_check` at `0x310B00` clears a side with `sc_clear(1, 25, 4, 26)` or `sc_clear(43, 25, 46, 26)`, or calls `satime_ko_after_clear` at `0x310CF0`, which restores `bacckup_g_h` into `gauge.s.h`. `sa_time_moji_send` at `0x310F70` decrements `time_timer` and indexes `sa_time_data_tbl` by `time_num` until it wraps at 5. `spgauge_control` at `0x30FF30` sets the gauge timer to `16`, `51`, or `25` and masks `sa_gauge_flash` with `~2`, `~4`, or `~1`. `samoji_control` switches on `max_rno`. `sast_control` switches on `time_rno` when `time` is set and on `max_rno` otherwise. `sast_color_chenge` stores colors `14`/`142`, `18`/`146`, or `17`/`145`. `Passive14_0081` was the debug-map name on `sa_color_chenge`, which stores `18`/`146` or `17`/`145` from `kind`. `sa_moji_trans` draws the time digits at `(1, 25)` and `(43, 25)`. `spgauge_sound_request` plays sound `107` plus the side when `store` is above `spg_level`. `tr_spgauge_cont_init2` fills one gauge and calls `sa_moji_trans`. `ppgWorkInitializeApprication` at `0x373100` clears the `Texture.be` and `Palette.be` bytes, including 24 `mts` textures at stride `0x64`. `ppgPurgeFromVRAM` switches on types `0` through `5`. `ppgPurgeTextureFromVRAM` walks `Texture.total` at offset `6` and `handle` at offset `8`. `ppgPurgePaletteFromVRAM` walks `Palette.total` at offset `2` and `handle` at offset `4`. `flPS2PurgeTextureFromVRAM` and `flPS2PurgePaletteFromVRAM` index `FLTexture` (`0x3C` bytes) and call through when `vram_on_flag` at offset `0x35` is set. The retail copies omit the `ERR_STOP` checks. `flPS2GetVramFreeArea` reserves low and high handles, and `flPS2SearchVramSpace` rejects a block that would pass `0x4000`. `Reboot_Program` at `0x373680` flips three times, shuts down ADX, and calls `LoadExecPS2` with `reboot_param` at `gp-20496`.

`check_shortcut` at `0x315680` returns 1 when `end_no_cut` is clear and the winner's switches include `0xFF0`. `set_credit_string` at `0x3156E0` centers a credit on `bgw[5]` and skips a leading `0x3F` or `0x60`. `staff_credits` at `0x3157F0` requests BGM `0x3F` and fades with `0x88` or `0x4E`. `stngauge_cont_init` at `0x316480` clears two `SDAT` slots of `0xA` bytes, sets `stimer` to 2, and stores `genkai / 8` in `slen`. `stngauge_cont_main` at `0x316620` was `Passive14_0147`; it runs `stngauge_control` when `gauge_stop_flag` is clear. `stngauge_control` at `0x316730` sets `proccess_dead` when `dead_flag` is set, and flashes when `routine_no[2]` is `0x19`. `stngauge_work_clear` zeroes both slots and sets `stimer` to 2. `Switch_Screen_Init` at `0x316DB0` was `Passive14_0155`; it sets `Forbid_Break`, `Exec_Wipe`, and `Stop_SG` to 1 and `Gap_Timer` to 4. `Switch_Screen` and `Switch_Screen_Revival` clear `Exec_Wipe` and `Stop_Combo` once `Gap_Timer` expires. `Convert_User_Setting` at `0x316EC0` masks the pad with `0x400F` and folds `Shot[0]` through `Shot[7]`; the retail copy omits the `Debug_w[70] == 16` shortcut. `Clear_Personal_Data` at `0x317230` stores `Used_char` as `0xFF`, `Last_Player_id` as `-1`, and `SC_Personal_Time` as `481`, then zeroes ten `EM_History` bytes. `Check_Count_Cut` returns the new switches masked with `0xFF0`. `Disp_Personal_Count` draws at `DE_X + 14` with attribute 9. `Setup_Play_Type` sets `Play_Type` when both `Operator_Status` bytes have bits `0x7F` set. `Clear_Flash_No` zeroes the eight `F_No` bytes and `Personal_Disp_Flag`. `Cut_Cut_Cut` returns 1 when `Demo_Flag` is set and a side's `operator` and switches `0xFF0` are both set. `Score_Sub` at `0x3178F0` returns when `Mode_Type` is 3 or 4 or `omop_cockpit` is clear, and splits the score from `10000000`.

`Disp_Win_Record` at `0x317BD0` returns when `omop_cockpit` is clear. Mode 0 draws one side at column 5 or 43, and modes 1 and 2 draw `VS_Win_Record`. `Disp_Win_Record_Sub` prints `WIN` or `WINS` and splits the count by 100 and 10. `Button_Cut_EX` decrements the timer and returns 1 on zero or when switches `0xFF0` arrive inside the limit. `Setup_Target_PL` returns `Winner_id` when `Play_Type` is 1. `Setup_Final_Grade` copies `LOSER` into the grade fields only when `Break_Com` is 0. `Clear_Win_Type` zeroes six win-type rows for `i < 4`. `Clear_Disp_Ranking` stores `-1` into four rank slots. `Meltw` expands a bit-flagged halfword stream, masks a back-reference with `0x7FF`, and returns when both length and count are 0. `Setup_ID` sets `Player_id` to 1 when `Operator_Status[0]` is 0. `Game_Data_Init` sets the analog-cut flag when either pad's switches equal `0x330`, then zeroes `AnalogStick` in six save slots. `Setup_IO_ConvDataDefault` copies 12 bytes into `Convert_Buff[1][id]`. `Save_Game_Data` indexes `Time_Limit_Data` (`30`, `60`, `99`, `-1`). `Copy_Save_w` maps those limits back to `0`, `1`, `2`, and `3`, then copies 8 shots and 20 ranking entries.

`Copy_Check_w` at `0x318A20` copies four pages of 12 convert bytes into `Check_Buff`, then copies 32 bytes of `extra_option`. `Setup_Default_Game_Option` copies the 520-byte default save into six slots and zeroes `sum` at offset `516`. `Check_Change_Contents` copies `Convert_Buff[3][0][0]` and slots `4` through `11`, then returns 1 on a mismatch. `Check_Menu_Task` returns 1 when modes 3 and 4 have both routine numbers equal to 7, or when `task[3].condition` is 1. `Setup_Limit_Time` adds 20 to the difficulty-table halfword and stores `1241` or `1061` from `Country`. `Setup_Training_Difficulty` divides `Limit_Time - 481` by 5 and clamps the minimum at 0. `Setup_BG` sets `Unsubstantial_BG` and writes X and Y into `bgw` at stride `144`. `Setup_Virtual_BG` writes the same positions and leaves the flag alone. `BG_move` walks four flags. `Basic_Sub` copies `bgw[0]` position into `old_pos_x` and then runs the same six effect calls as `Basic_Sub_Ex`. `Check_PL_Load` returns 1 only when both player queue checks succeed. `BG_Draw_System` starts its mask at 1 and shifts it for four screens, then branches on `Play_Game` 0 and 1. `Check_Demo_Data` returns 0 when the high bit `0x8000` is set and stores the low 15 bits into `Demo_Timer`. `Cut_Cut_C_Timer` decrements `C_Timer` and clears it when `Cut_Cut_Cut` is set. `Switch_Priority_76` stores 7 and 1. `Cut_Cut_Sub` returns 1 when `Demo_Flag` is clear, and otherwise returns its argument when a side's `operator` and switches `0xFF0` are both set.

`Cut_Cut_Loser` at `0x319940` returns 1 when a side's `Round_Operator` and switches `0xFF0` are both set. `Soft_Reset_Sub` at `0x3199A0` fades out, calls `sound_all_off` and `SsBgmHalfVolume(0)`, and readies task 5 with `Game_Task` when that task's condition is 0. The retail copy omits the `Usage == 7` debug task. `Reset_Sub0` zeroes pause, play, and both replay statuses and stores `Present_Mode` as 1. `Check_Replay` returns when `Demo_Flag` is clear. Play mode 1 sets both statuses to 1, clears a side whose operator is 0, stores `0xFFFF` in both `Condense_Buff` slots, and clears 29768 bytes at `Replay_w`. Modes 3 and 4 fill 7198 halfwords with `0xF000`. Play mode 3 sets both statuses to 3 and copies the stored handicaps back. `Setup_Replay_Header` stores the stage, both handicaps, and a two-player loop of character, super art, color, and operator, then copies the four random halfwords and `Champion` and zeroes `full_data`. `Get_Replay_Header` copies those fields back, sets `New_Challenger` to `Champion ^ 1`, and stores `Control_Time` and `Difficulty`. `Check_Replay_Status` returns when `Demo_Flag` is clear. Status 1 calls `Get_Replay`, status 3 calls `Replay`, status 2 zeroes that side's switches, and status 99 returns with no print. `Get_Replay` returns when `Game_pause` is `0x81`. It increments `Demo_Timer` while the switches match and the timer stays under 16, and otherwise calls `Setup_Replay_Buff`. The retail copy omits `Disp_Rec_Time`. `Setup_Replay_Buff` stores the switch and returns when `Condense_Buff` is `0xFFFF`. Otherwise it packs `(Demo_Timer - 1) << 12` with the low 12 switch bits and stores status 99 past halfword 7197. `Passive14_0203` was the debug-map name on `Replay` at `0x31A3F0`. When `Demo_Ptr` passes `key_buff[PL_id][7198]` it sets both statuses to 2, and when `Mode_Type` is 5 it exits task 4, readies task 3, and stores 13 in `task[3].r_no[0]`. It returns when `Game_pause` is `0x81`. When `Demo_Timer` is 0 it loads the packed halfword and masks `0xFFF` and `0xF000`.

`Check_SysDir_Page` at `0x31A620` counts 20 `PL_Color` bytes, divides by 5, clamps the result at 3, and adds 6. The retail copy omits the `Debug_w[52]` shortcut. `Clear_Flash_Init` zeroes `Synchro_No` and `Flash_Synchro` and stores the level. `Clear_Flash_Sub` subtracts or adds that level and clamps the flash at 1 and 127. `Copy_Key_Disp_Work` copies eight shots and the vibration byte from both pads of `save_w[1]` into `Convert_Buff[1]`. `Check_Extra_Setting` copies `extra_option` from `save_w[0]` into `save_w[1]` from each `Ex_Page_Data` index through 7, then returns 1 when one of the first four entries differs. `All_Clear_Random_ix` zeroes the four random halfwords. `All_Clear_Timer` zeroes `system_timer`, `Game_timer`, and `players_timer`. `Setup_Net_Random_ix` stores a zero byte into those same four halfwords. `Request_Fade` sets `Fade_Flag`, stores the fade code, sets `Forbid_Break`, and returns 1 only when the flag was clear. `Check_Fade_Complete_SP` returns `Fade_Flag ^ 1`. `Check_Fade_Complete` returns 0 while the flag is set and otherwise sets `Forbid_Break` and returns 1. `Check_Ranking` at `0x31AB40` stores name bytes `12`, `10`, and `25` and sets the score to `Continue_Coin + Score`. `Check_Partners_Rank` increments the other side and stores `-1` above 4. `Check_Sort_Score` and `Check_Sort_Wins` insert a 20-byte rank entry when the score or the win count is lower, using slots `0` and `5`. `Check_Sort_CPU_Grade` and `Check_Sort_Grade` do the same at slots `10` and `15`. `Check_CPU_Grade_Score` compares `cpu_grade` and then `score`. `Check_Grade_Score` compares `grade` and then `wins`.

`Disp_Digit16x24` at `0x31B9E0` draws a zero with color 15 when the score is 0, then splits the score from `10000000` by 10 and steps the column by 2. `Passive14_0226` was the debug-map name on `Disp_Copyright` at `0x31BBB0`. Countries 1, 2, 3, 7, and 8 draw the Capcom Ltd. line at `(386, 208)`. Countries 4, 5, and 6 draw the U.S.A. line at `(386, 212)` and the Ltd. line at y `202`.

`Initialize_EM_Candidate` at `0x31BC70` fills 16 candidate bytes with `0xFF`, then fills eight slots from `Check_EM_Buff` and stores the middle boss at index 8. Index 9 is 0 unless `My_char` is 0. `Setup_Candidate_Buff` walks characters 1 through 19 and skips the player's character, character 17, the middle boss, and a set `Break_Com` bit. `Check_EM_Sub` rejects `0xFF` and holds characters 2, 6, 8, and 11 until index 4, character 14 until index 6, and character 13 while `ok_urien` is set and the index is under 4. `Check_Same_CPU` returns when `VS_Index` is at least 9 or the character is unchanged. `Passive14_0234` is `All_Clear_Suicide`, which zeroes eight `Suicide` bytes and four `Menu_Suicide` bytes. `Clear_Break_Com` zeroes 20 `Break_Com` bytes. `Check_Off_Vib` returns immediately. `Flash_Violent` returns 1. `Passive14_0235` is `Init_load_on_memory_data`. It loads colors `0x9C`/`0x18`, `0x9D`/`0x1F`, and `0x14`/`2`, then textures `0x72A0` and `0x7F30`, and stores `my_mts` 17, `current_colcd` `0x1FF`, `my_clear_level` `0x90`, and `work_id` 16 on both demo works. `setup_GILL_exsa_obj` pulls effect work 5, stores patterns `0x9020` through `0x9036` in two loops of 8 and 10, and returns -1 when no work is free. `setup_GILL_Opening_Ceremony` returns 1. `Passive14_0237` is `setup_bonus_car_parts`, which returns immediately. `setup_dma_group` loads the pattern with key 2. `reset_dma_group` passes the pattern through. `set_conn_sprite` returns 1 when `num_of_conn` is 0 and otherwise copies each connector onto `dmwk_moji` and returns 2. `all_cgps_put_back` returns immediately. `Mtrans_use_trans_mode` returns when `mts_ok.be` is 0 or `No_Trans` is set. The retail copy omits the uninitialized-MTS print. It masks `current_colcd` with `0x1FF`, stores clear level `0x90` when `my_col_mode` has bit `0x400`, and switches on modes 17, 18, 20, 33, 34, and 36.

`exchange_current_colcd` at `0x31CD60` switches on `work_id` 1, 8, 16, 32, and 64. Case 1 replaces the color with `id * 8`. Cases 8 and 16 use the master's `id * 8 + 4` for ids `0x93` and `0x94`. Cases 32 and 64 copy the master's `id * 8` or `id * 8 + 1` when the color codes match. `sort_push_request` returns 0 when `my_mts` is 0, sets bit 8 of `current_colcd` for a flipped work id 1 or 32, and returns 1 when `disp_flag` or `cg_number` is 0. `sort_push_request3` calls `set_conn_sprite` with `base_y_pos` and returns 1 when that call returns 1. `sort_push_request4` stores bright type 1 and level 7 when `judge_flag` is set, the id is not `0x4C` or `0x46`, and `position_z` is below 72. `sort_push_request8` selects `my_mts` 2 when `cg_number` is at least `0x748F` and otherwise 14, then forces 14 when `my_col_code` masked with `0x1FF` is at least 32. `sort_push_requestA` and `sort_push_requestB` share one body. A passes `base_y_pos` to the matrix call and B passes 0. Both read `box_color_attr` at `0x4B37E0` and blink from `Interrupt_Timer` masks `0x80`, `0x40`, and `0x20`. Retail has no `sort_push_request2` or `set_judge_area_sprite` in this span. `shadow_setup` converts `bsy` and `PrioBase[kage_prio]` and requests one sorted shadow. `shadow_drawing` writes the shadow work at `0x610030`, clamps the character at 0 and 28, and adds `0x7308`. It omits the `Debug_w[0x23]` test. `get_kage_width` returns 0 at or below 0, 16 at or above 64 after dividing by 4, and otherwise `gkw_table` at `0x4B3800`.

`sag_ikinari_max` at `0x31DF50` returns 1 when both `omop_spmv_ng_table2` words have bit `0x40000`. `check_use_all_SA` returns `system_dir[Present_Mode].contents[9][0]` when `Direction_Working` is set. `check_without_SA` returns whether `contents[5][0]` is 0. `init_omop` clears the four move words, sets bits `0x400000` and `0x800000` on `table2[0]`, and ORs `sysdir_base_move` at `0x4B3850` for both `My_char` entries. `system_dir` is at `0x612340` with stride 72. `get_extra_option_parameter` indexes `omop_guard_type` at `0x4B3840` and ORs `0x80000`, `0x10000`, or `0x90000` from contents row 1. `get_system_direction_parameter` walks the 10 by 7 direction grid, including `GuardCheck` at `save_w + 0x24`, and copies the player-0 results onto player 1.

`sync_fam_set3` at `0x31E940` reads `bg_w` at `0x4F2030`. The low nibble of `chase_flag` selects `chase_xy[0]` over `wxy[0]`, and the high nibble selects `chase_xy[1]` over `xy[1]`. Both X values subtract `pos_offset`. `quake_x_tbl` at `0x448970` is added only when `quake_x_index` is positive. `quake_y_tbl` at `0x448A00` is always added. It stores `position_x`, `abs_x`, `position_y`, and `abs_y`, then calls the screen move and family setup. `range_x_check` uses family `my_family - 1` and returns 1 when `xyz[0].disp.pos` is inside `pos - 193` through `pos + 193`, or through `pos + 225` when `hit_stop` is `-77`. `range_x_check3` uses `192` plus the optional range. `range_y_check` returns 1 when `xyz[1].disp.pos` is inside `pos - 32` through `pos + 256`. `add_x_sub` and `add_x_sub2` are identical: `xyz[0].cal` adds `mvxy.a[0].sp`, then that speed adds `mvxy.d[0].sp`. `add_y_sub` and `add_y_sub2` do the same on Y. `obr_no_disp_check` ORs four global bytes and returns 1 when any is set. `disp_pos_trans_entry` and `disp_pos_trans_entry5` are identical. Both return when that check is set, copy the display positions, and call `sort_push_request4`. `disp_pos_trans_entry_r` also requires `range_x_check` and adds 1 to X. `disp_pos_trans_entry_r4` requires `range_y_check` and does not add 1. `Passive15_0035` is `disp_pos_trans_entry_s` at `0x31F1B0`. It calls the suzi sync, then adds 1 to `position_x`. `disp_pos_trans_entry_rs` does that only after `range_x_check`. `pl_eff_trans_entry` copies both display positions and calls `sort_push_request`.

`eff_hit_check` at `0x31F2E0` skips the work when one global byte is set. A second global byte gates the `type` path. Both paths add `eff_hit_check_sub` for `plw[0]` at `0x541520` and `plw[1]` at `0x54198C` into `eff_hit_flag[wu.type]`. `eff_hit_check_sub` returns 0 unless `routine_no[1]` is 1 and `routine_no[2]` is from 14 through 23, then indexes `pl_hit_eff` at `0x4B3950` by `player_number`. `eff_hit_check2` passes `where_type` into `eff_hit_check_sub2`, which selects `h_bod->body_dm[where_type]`. `hit_check_subroutine_yu` flips both hit boxes on `rl_flag`, rejects an X or Y miss, and subtracts 40 from the effect Y. `eff_hit_flag_clear` zeroes 11 halfwords. `compel_dead_check` returns 1 only when `compel_flag` and `dead_f` are both set. `win_lose_work_clear` zeroes `a_rno`, both `win_rno` and `win_free` slots, `lose_rno[0]` through `[2]`, and both `lose_free` slots.
