#include <stdint.h>
#include "uart.h"

static int memtest_check_range(uint32_t start, uint32_t end, uint32_t *err_addr, uint8_t *exp_out, uint8_t *got_out)
{
    uint32_t addr;
    int errors = 0;

    /* Pass 1: address-dependent pattern (catches address aliasing & lane mixups) */
    for (addr = start; addr <= end; addr++) {
        volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)addr;
        uint8_t pat = (uint8_t)((addr ^ (addr >> 8) ^ (addr >> 16)) & 0xFFu);
        *p = pat;
        if (addr == 0xFFFFFFFFu) break;
    }

    for (addr = start; addr <= end; addr++) {
        volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)addr;
        uint8_t exp = (uint8_t)((addr ^ (addr >> 8) ^ (addr >> 16)) & 0xFFu);
        uint8_t got = *p;
        if (got != exp) {
            if (errors == 0) {
                *err_addr = addr;
                *exp_out = exp;
                *got_out = got;
            }
            errors++;
        }
        if (addr == 0xFFFFFFFFu) break;
    }

    /* Pass 2: alternating 0x55 / 0xAA across adjacent bytes */
    for (addr = start; addr <= end; addr++) {
        volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)addr;
        *p = (addr & 1u) ? 0xAAu : 0x55u;
        if (addr == 0xFFFFFFFFu) break;
    }

    for (addr = start; addr <= end; addr++) {
        volatile uint8_t *p = (volatile uint8_t *)(uintptr_t)addr;
        uint8_t exp = (addr & 1u) ? 0xAAu : 0x55u;
        uint8_t got = *p;
        if (got != exp) {
            if (errors == 0) {
                *err_addr = addr;
                *exp_out = exp;
                *got_out = got;
            }
            errors++;
        }
        if (addr == 0xFFFFFFFFu) break;
    }

    return errors;
}

void cmd_memtest(uint32_t start, uint32_t end)
{
    uint32_t err_addr = 0;
    uint8_t exp = 0, got = 0;
    int errs;

    if (end < start) {
        uart_puts("ERR: end < start\r\n");
        return;
    }

    uart_puts("Testing ");
    uart_puthex32(start);
    uart_puts("-");
    uart_puthex32(end);
    uart_puts("...\r\n");

    errs = memtest_check_range(start, end, &err_addr, &exp, &got);
    if (errs == 0) {
        uart_puts("PASS: 0 errors\r\n");
    } else {
        uart_puts("FAIL at ");
        uart_puthex32(err_addr);
        uart_puts(" exp=");
        uart_puthex8(exp);
        uart_puts(" got=");
        uart_puthex8(got);
        uart_puts("\r\n");
    }
}
