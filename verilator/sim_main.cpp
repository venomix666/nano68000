#include "Vnano68000_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <cstdint>
#include <cstdlib>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    uint64_t max_cycles = 200;
    for (int i = 1; i < argc; ++i) {
        if (std::string(argv[i]) == "--cycles" && i + 1 < argc) {
            max_cycles = std::strtoull(argv[++i], nullptr, 10);
        }
    }

    Verilated::traceEverOn(true);
    auto* top = new Vnano68000_top;
    auto* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");

    uint64_t sim_time = 0;
    top->clk_i = 0;
    top->rst_i = 1;
    top->eval();
    tfp->dump(sim_time++);

    for (uint64_t cyc = 0; cyc < max_cycles; ++cyc) {
        // Hold active-high reset for the first 16 clock cycles
        top->rst_i = (cyc < 16) ? 1 : 0;

        top->clk_i = 1;
        top->eval();
        tfp->dump(sim_time++);

        top->clk_i = 0;
        top->eval();
        tfp->dump(sim_time++);
    }

    tfp->close();
    delete tfp;
    delete top;
    return 0;
}
