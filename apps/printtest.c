#include <stdint.h>

/* Adjust these to match your UART peripheral and SDRAM stack top */
#define UART_BASE        0x00800000u
#define UART_STAT        (*(volatile uint8_t *)(UART_BASE + 2u))
#define UART_DATA        (*(volatile uint8_t *)(UART_BASE + 0u))
#define UART_TX_RDY_BIT  0u

static void uart_putc(char c)
{
    while ((UART_STAT & (uint8_t)(1u << UART_TX_RDY_BIT)) == 0u) {
        /* Wait until TX ready */
    }
    UART_DATA = (uint8_t)c;
}

static void uart_print(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

void c_entry(void)
{
    uart_print("Hello, world!\r\n");
}
