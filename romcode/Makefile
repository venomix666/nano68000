AS      := vasmm68k_mot
ASFLAGS := -Fbin -m68000 -nosym

all:	install

install: nano68000.hex
	cp nano68000.hex ../src
	cp nano68000.hex ../verilator

nano68000.bin: nano68000.asm
	$(AS) $(ASFLAGS) -o $@ $<

nano68000.hex: nano68000.bin gen_hex.py
	python3 gen_hex.py --words 4096 $< $@

clean:
	$(RM) -f *.bin *.hex
