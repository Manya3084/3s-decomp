/* Link the retail SLUS-20949 code and payload at the disc virtual addresses. */
OUTPUT_FORMAT("elf32-tradlittlemips", "elf32-tradlittlemips", "elf32-tradlittlemips")
OUTPUT_ARCH(mips)
ENTRY(func_00100008)

SECTIONS
{
    .text 0x00100000 : {
        *(.text)
    }
    .data : {
        *(.data)
    }
    .bss : {
        . = . + 0x16DA80;
    }
    /DISCARD/ : {
        *(.reginfo)
        *(.MIPS.abiflags)
        *(.pdr)
        *(.comment)
        *(.gnu.attributes)
    }
}
