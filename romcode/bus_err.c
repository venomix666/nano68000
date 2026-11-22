#include <stdint.h>
#include "uart.h"

struct bus_error_frame {
    uint16_t func_code;
    uint16_t addr_hi;
    uint16_t addr_lo;
    uint16_t ir;
    uint16_t sr;
    uint16_t pc_hi;
    uint16_t pc_lo;
};

void bus_error_c(const struct bus_error_frame *f);

__attribute__((used))
void bus_error_entry(void)
{
    __asm__ volatile (
        "ori.w   #0x0700, %%sr\n\t"
        "move.l  %%sp, -(%%sp)\n\t"
        "jsr     bus_error_c\n\t"
        "addq.l  #4, %%sp\n\t"
        "1:\n\t"
        "bra.s   1b"
        :
        :
        : "memory"
    );
}

void bus_error_c(const struct bus_error_frame *f)
{
    uint32_t fault_addr = ((uint32_t)f->addr_hi << 16) | (uint32_t)f->addr_lo;
    uint32_t pc         = ((uint32_t)f->pc_hi << 16)   | (uint32_t)f->pc_lo;
    uint16_t fc         = f->func_code;

    uart_puts("\r\n*** BUS ERROR ***\r\n");

    uart_puts("ADDR: 0x");
    uart_puthex32(fault_addr);
    uart_puts("  PC: 0x");
    uart_puthex32(pc);
    uart_puts("\r\n");

    uart_puts("SR:   0x");
    uart_puthex16(f->sr);
    uart_puts("  IR: 0x");
    uart_puthex16(f->ir);
    uart_puts("  FC: 0x");
    uart_puthex16(fc);
    uart_puts("\r\n");

    uart_puts("RW:   ");
    uart_puts((fc & (1U << 4)) ? "READ" : "WRITE");
    uart_puts("  TYPE: ");
    uart_puts((fc & (1U << 3)) ? "DATA/OTHER" : "INSN");
    uart_puts("  FC[2:0]: ");
    uart_puthex_nibble((uint8_t)(fc & 0x07U));
    uart_puts("\r\n");
}
