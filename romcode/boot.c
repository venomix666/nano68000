#include <stdint.h>

#define UART_DATA (*(volatile uint8_t *)0x800000)

static void uart_putc(char c)
{
    UART_DATA = (uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

void start(void)
{
    uart_puts("Hello\r\n");

    for (;;) {
        __asm__ volatile ("nop");
    }
}

void bus_error_handler(void)
{
    uart_puts("Bus error\r\n");
}
