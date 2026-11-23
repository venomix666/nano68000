#include <stdint.h>
#include "uart.h"

static int hex_nibble(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

static int read_hex_byte(uint8_t *out, uint32_t *running_sum)
{
    int hi = hex_nibble(uart_getc());
    int lo = hex_nibble(uart_getc());
    uint8_t val;

    if (hi < 0 || lo < 0) return -1;
    val = (uint8_t)((hi << 4) | lo);
    if (out) *out = val;
    if (running_sum) *running_sum += val;
    return 0;
}

/* Returns 0 on normal completion (S7/S8/S9), 1 if entry point was captured in *entry_out,
 * or negative value on format/checksum error. */
int srec_load(uint32_t *entry_out, int *has_entry)
{
    int records = 0;
    if (has_entry) *has_entry = 0;

    uart_puts("Send S-records (S7/S8/S9 to finish)...\r\n");

    for (;;) {
        char c = uart_getc();
    char type;
        uint8_t count = 0;
        uint32_t sum = 0;
        uint32_t addr = 0;
        int addr_len = 0;
        int is_data = 0;
        int is_end = 0;
        int i, data_len;
        uint8_t byte_val = 0, checksum = 0;

        /* Skip stray CR/LF or whitespace between lines */
        if (c == '\r' || c == '\n' || c == ' ' || c == '\t') continue;
        if (c != 'S' && c != 's') {
            uart_puts("\r\nERR: expected 'S'\r\n");
            return -1;
        }

        type = uart_getc();
        if (read_hex_byte(&count, &sum) < 0) {
            uart_puts("\r\nERR: bad count hex\r\n");
            return -2;
        }

        switch (type) {
            case '0': /* Header record */
                addr_len = 2;
                break;
            case '1': /* 16-bit address data */
                addr_len = 2;
                is_data = 1;
                break;
            case '2': /* 24-bit address data */
                addr_len = 3;
                is_data = 1;
                break;
            case '3': /* 32-bit address data */
                addr_len = 4;
                is_data = 1;
                break;
            case '5': /* Optional record count */
            case '6':
                addr_len = (type == '5') ? 2 : 3;
                break;
            case '7': /* 32-bit entry termination */
                addr_len = 4;
                is_end = 1;
                break;
            case '8': /* 24-bit entry termination */
                addr_len = 3;
                is_end = 1;
                break;
            case '9': /* 16-bit entry termination */
                addr_len = 2;
                is_end = 1;
                break;
            default:
                uart_puts("\r\nERR: unsupported S-record type\r\n");
                return -3;
        }

        if (count < (uint8_t)(addr_len + 1)) {
            uart_puts("\r\nERR: short record count\r\n");
            return -4;
        }

        for (i = 0; i < addr_len; i++) {
            if (read_hex_byte(&byte_val, &sum) < 0) {
                uart_puts("\r\nERR: bad address hex\r\n");
                return -5;
            }
            addr = (addr << 8) | byte_val;
        }

        data_len = (int)count - addr_len - 1;
        for (i = 0; i < data_len; i++) {
            if (read_hex_byte(&byte_val, &sum) < 0) {
                uart_puts("\r\nERR: bad data hex\r\n");
                return -6;
            }
            if (is_data) {
                volatile uint8_t *dst = (volatile uint8_t *)(uintptr_t)(addr + (uint32_t)i);
                *dst = byte_val;
            }
        }

        /* Read checksum byte without adding it to running sum */
        if (read_hex_byte(&checksum, 0) < 0) {
            uart_puts("\r\nERR: bad checksum hex\r\n");
            return -7;
        }

        if (((~sum) & 0xFFu) != (uint32_t)checksum) {
            uart_puts("\r\nERR: checksum mismatch at addr ");
            uart_puthex32(addr);
            uart_puts("\r\n");
            return -8;
        }

        if (is_data) records++;

        if (is_end) {
            if (entry_out) *entry_out = addr;
            if (has_entry) *has_entry = 1;
            uart_puts("OK: loaded ");
            uart_puthex32((uint32_t)records);
            uart_puts(" records, entry=");
            uart_puthex32(addr);
            uart_puts("\r\n");
            return 0;
        }
    }
}
