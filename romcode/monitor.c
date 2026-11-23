#include <stdint.h>
#include "uart.h"

#define LINE_BUF_LEN 64

extern void cmd_memtest(uint32_t start, uint32_t end);
extern int srec_load(uint32_t *entry_out, int *has_entry);

static int hex_nibble(char c)
{
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return 10 + (c - 'a');
    }
    if (c >= 'A' && c <= 'F') {
        return 10 + (c - 'A');
    }
    return -1;
}

static const char *skip_spaces(const char *s)
{
    while (*s == ' ' || *s == '\t') {
        s++;
    }
    return s;
}

/* Parses an optional 0x/0X prefix and 1..8 hex digits.
 * Advances *cursor past the parsed number and returns 1 on success, 0 on failure. */
static int parse_hex_u32(const char **cursor, uint32_t *out)
{
    const char *p = skip_spaces(*cursor);
    uint32_t val = 0;
    int count = 0;

    if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) {
        p += 2;
    }

    for (;;) {
        int nib = hex_nibble(*p);
        if (nib < 0) {
            break;
        }
        val = (val << 4) | (uint32_t)nib;
        count++;
        p++;
    }

    /* Require whitespace or end-of-string after the number */
    if (count == 0 || (*p != '\0' && *p != ' ' && *p != '\t')) {
        return 0;
    }

    *out = val;
    *cursor = p;
    return 1;
}

static void read_line(char *buf, int max_len)
{
    int idx = 0;

    for (;;) {
        char c = uart_getc();

        if (c == '\r' || c == '\n') {
            uart_puts("\r\n");
            buf[idx] = '\0';
            return;
        }

        if ((c == '\b' || c == 0x7f) && idx > 0) {
            idx--;
            uart_puts("\b \b");
            continue;
        }

        if (idx < (max_len - 1) && (uint8_t)c >= 0x20U && (uint8_t)c < 0x7fU) {
            buf[idx] = c;
            idx++;
            uart_putc(c);
        }
    }
}

static void cmd_dump(const char *args)
{
    uint32_t addr = 0;
    uint32_t len = 64;

    if (!parse_hex_u32(&args, &addr)) {
        uart_puts("Usage: d <addr> [len]\r\n");
        return;
    }

    {
        uint32_t parsed_len = 0;
        if (parse_hex_u32(&args, &parsed_len) && parsed_len > 0U) {
            len = parsed_len;
        }
    }

    const volatile uint8_t *p = (const volatile uint8_t *)(uintptr_t)addr;

    for (uint32_t off = 0; off < len; off += 16U) {
        uart_puthex32(addr + off);
        uart_puts(": ");

        for (uint32_t i = 0; i < 16U; i++) {
            if (off + i < len) {
                uint8_t b = p[off + i];
                uart_puthex_nibble((uint8_t)(b >> 4));
                uart_puthex_nibble((uint8_t)(b & 0x0fU));
                uart_putc(' ');
            } else {
                uart_puts("   ");
            }
        }

        uart_puts(" |");
        for (uint32_t i = 0; i < 16U && (off + i) < len; i++) {
            char ch = (char)p[off + i];
            uart_putc(((uint8_t)ch >= 0x20U && (uint8_t)ch < 0x7fU) ? ch : '.');
        }
        uart_puts("|\r\n");
    }
}

static void cmd_write(const char *args)
{
    uint32_t addr = 0;
    uint32_t val = 0;

    if (!parse_hex_u32(&args, &addr) || !parse_hex_u32(&args, &val)) {
        uart_puts("Usage: w <addr> <val>\r\n");
        return;
    }

    *(volatile uint8_t *)(uintptr_t)addr = (uint8_t)(val & 0xffU);
    uart_puts("OK\r\n");
}

static void cmd_go(const char *args)
{
    uint32_t addr = 0;

    if (!parse_hex_u32(&args, &addr)) {
        uart_puts("Usage: g <addr>\r\n");
        return;
    }

    if ((addr & 1U) != 0U) {
        uart_puts("Error: odd jump address\r\n");
        return;
    }

    uart_puts("Jumping to 0x");
    uart_puthex32(addr);
    uart_puts("\r\n");

    typedef void (*entry_fn)(void);
    entry_fn fn = (entry_fn)(uintptr_t)addr;
    fn();
}

void monitor_run(void)
{
    char line[LINE_BUF_LEN];

    uart_puts("\r\nnano68000 Monitor Ready\r\n");

    for (;;) {
        uart_puts("mon> ");
        read_line(line, LINE_BUF_LEN);
        
        const char *p = skip_spaces(line);
        if (*p == '\0') {
            continue;
        }

        char cmd = *p++;
        if (*p != '\0' && *p != ' ' && *p != '\t') {
            uart_puts("Unknown command (type 'h' for help)\r\n");
            continue;
        }
        switch (cmd) {
            case 'd':
            case 'D':
                cmd_dump(p);
                break;
            case 'w':
            case 'W':
                cmd_write(p);
                break;
            case 'g':
            case 'G':
                cmd_go(p);
                break;
            case 't':
            case 'T':
                uint32_t start, end;
                if(!parse_hex_u32(&p, &start)) {
                    uart_puts("Illegal start address\r\n");
                    break;
                }

                if(!parse_hex_u32(&p, &end)) {
                    uart_puts("Illegal end address\r\n");
                    break;
                }
                cmd_memtest(start, end);
                break;
            case 's':
            case 'S':
                uint32_t entry = 0;
                int has_entry = 0;
                int rc = srec_load(&entry, &has_entry);
                if(rc == 0 && has_entry) {
                    uart_puts("Entry point: ");
                    uart_puthex32(entry);
                    uart_puts(" (use 'g ");
                    uart_puthex32(entry);
                    uart_puts("' to run)\r\n");
                }
                break;
            case 'h':
            case 'H':
            case '?':
                uart_puts("Commands:\r\n");
                uart_puts("  d <addr> [len]  - hex/ASCII memory dump\r\n");
                uart_puts("  w <addr> <val>  - write byte to address\r\n");
                uart_puts("  g <addr>        - call code at even address\r\n");
                uart_puts("  t <addr> <addr> - test memory between addrs\r\n");
                uart_puts("  s               - load S-record\r\n");
                uart_puts("  h               - help\r\n");
                break;
            default:
                uart_puts("Unknown command (type 'h' for help)\r\n");
                break;
        }
    }
}
