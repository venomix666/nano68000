CROSS_COMPILE ?= m68k-linux-gnu-
CC      := $(CROSS_COMPILE)gcc
LD      := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy
SIZE    := $(CROSS_COMPILE)size
AS 		:= $(CROSS_COMPILE)as

TARGET  := printtest
SRCS    := entry.s printtest.c
LDSCRIPT := printtest.ld

OBJS    := $(addsuffix .o,$(basename $(SRCS)))
ELF     := $(TARGET).elf
SREC    := $(TARGET).srec

CFLAGS  := -m68000 -ffreestanding -fno-builtin -O2 -Wall -Wextra -Werror
LDFLAGS := -T $(LDSCRIPT) -nostdlib
SRECFLAGS := -O srec --srec-forceS3
ASFLAGS := -m68000

.PHONY: all clean size

all: $(SREC) size

$(ELF): $(OBJS) $(LDSCRIPT)
	$(LD) $(LDFLAGS) $(OBJS) -o $@

&.o: %.s
	$(AS) $(ASFLAGS) $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(SREC): $(ELF)
	$(OBJCOPY) $(SRECFLAGS) $< $@

size: $(ELF)
	$(SIZE) $(ELF)

clean:
	rm -f $(OBJS) $(ELF) $(SREC)
