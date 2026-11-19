TOP       := nano68000_top
SIM_BIN   := obj_dir/V$(TOP)
HEX_FILE  := nano68000.hex
D		  := ../src
V_SRCS    := $D/nano68000_top.v $D/instram.v $D/bootrom.v $D/addr_decoder.v \
			 $D/fx68k/fx68k.sv $D/fx68k/fx68kAlu.sv $D/fx68k/uaddrPla.sv \
			 $D/UART/uart.v $D/UART/uart_rx.v $D/UART/uart_tx.v \
			 $D/UART/uart_rx_flex.v $D/UART/uart_tx_flex.v

VFLAGS    := --cc --exe --build -Wall \
			 -Wno-DECLFILENAME \
			 -Wno-WIDTHEXPAND \
			 -Wno-WIDTHTRUNC \
			 -Wno-BLKANDNBLK \
			 -Wno-MULTIDRIVEN \
			 -Wno-TIMESCALEMOD \
			 -Wno-INITIALDLY \
			 -Wno-UNOPTFLAT \
			 -Wno-COMBDLY \
			 -Wno-lint \
			 --trace

all: $(SIM_BIN)

$(SIM_BIN): $(V_SRCS) sim_main.cpp $(HEX_FILE)
	verilator $(VFLAGS) --top-module $(TOP) $(V_SRCS) sim_main.cpp

run: $(SIM_BIN)
	./$(SIM_BIN) --cycles 800 +trace

clean:
	rm -rf obj_dir dump.vcd
