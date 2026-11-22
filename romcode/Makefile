CROSS   := m68k-linux-gnu-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size

TARGET  := nano68000
ELF     := $(TARGET).elf
BIN     := $(TARGET).bin
HEX     := $(TARGET).hex
MAP     := $(TARGET).map
LST     := $(TARGET).lst

LDSCRIPT := rom.ld
SRCS     := vectors.c boot.c
OBJS     := $(SRCS:.c=.o)

CFLAGS  := -m68000 -Os -ffreestanding -nostdlib -Wall -Wextra -Werror
LDFLAGS := -m68000 -ffreestanding -nostdlib -Wl,--build-id=none -Wl,-T,$(LDSCRIPT) -Wl,-Map,$(MAP)

.PHONY: all gen_hex clean inspect disasm

all: $(BIN) gen_hex inspect

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@
	@ls -lh $@

gen_hex: $(BIN)
	@python3 -c 'import pathlib; data = pathlib.Path("$(BIN)").read_bytes(); \
		target_bytes = 4096 * 2; \
		assert len(data) <= target_bytes, f"ROM binary ({len(data)} bytes) exceeds {target_bytes} bytes"; \
		data = data.ljust(target_bytes, b"\x00"); \
		lines = [data[i:i+2].hex() for i in range(0, target_bytes, 2)]; \
		pathlib.Path("$(HEX)").write_text("\n".join(lines) + "\n")'
	@echo "Wrote $(HEX) (4096 x 16-bit big-endian words)"
	cp $(HEX) ../verilator
	cp $(HEX) ../src

$(ELF): $(OBJS) $(LDSCRIPT)
	$(CC) $(LDFLAGS) $(OBJS) -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

inspect: $(ELF)
	$(SIZE) -A $<
	@echo "--- First 32 bytes of $(BIN) ---"
	@hexdump -C -n 32 $(BIN)

disasm: $(ELF)
	$(OBJDUMP) -d -h -t $(ELF) > $(LST)
	@echo "Wrote $(LST)"

clean:
	rm -f $(OBJS) $(ELF) $(BIN) $(HEX) $(MAP) $(LST)
