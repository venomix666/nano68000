TOP       := nano68000_top
SIM_BIN   := obj_dir/V$(TOP)
HEX_FILE  := nano68000.hex
D		  := ../src
V_SRCS    := $D/nano68000_top.v $D/instram.v $D/bootrom.v \
			 $D/fx68k/fx68k.sv $D/fx68k/fx68kAlu.sv $D/fx68k/uaddrPla.sv
VFLAGS    := --cc --exe --build -Wall \
			 -Wno-DECLFILENAME \
			 -Wno-WIDTHEXPAND \
			 -Wno-WIDTHTRUNC \
			 -Wno-BLKANDNBLK \
			 -Wno-MULTIDRIVEN \
			 -Wno-TIMESCALEMOD \
			 -Wno-INITIALDLY \
			 -Wno-UNOPTFLAT \
			 -Wno-lint \
			 --trace

all: $(SIM_BIN)

$(SIM_BIN): $(V_SRCS) sim_main.cpp $(HEX_FILE)
	verilator $(VFLAGS) --top-module $(TOP) $(V_SRCS) sim_main.cpp

run: $(SIM_BIN)
	./$(SIM_BIN) --cycles 200 +trace

clean:
	rm -rf obj_dir dump.vcd
