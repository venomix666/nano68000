# nano68000
68k based SoC for the Tang Nano 20K - work in progress  

Current memory map:  
| Start addr | Stop addr | Description |
|------------|-----------|-------------|
| 0x000000 | 0x001FFF | SDRAM / ROM overlay |
| 0x001FFF | 0x7FFFFF | SDRAM |  
| 0x800000 | 0x80000F | UART |
| 0x800010 | 0x80001F | Address decoder registers | 
| 0x810000 | 0x8103FF | SD card registers and sector buffer |
| 0xFE0000 | 0xFEFFFF | 64k of block RAM (will be replaced by graphics RAM) |
| 0xFFE000 | 0xFFFFFF | ROM |



