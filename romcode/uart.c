#include "uart.h"

#define UART_TX_DATA (*(volatile uint8_t *)0x800000)
#define UART_TX_READY (*(volatile uint8_t *)0x800002)
#define UART_RX_DATA (*(volatile uint8_t *)0x800004)
#define UART_RX_AVAIL (*(volatile uint8_t *)0x800006)

void uart_putc(char c)
{
    while(UART_TX_READY == 0U);
    UART_TX_DATA = (uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

uint8_t uart_avail(void)
{
    return UART_RX_AVAIL;
}

// Blocking uart getc
uint8_t uart_getc(void)
{
    while(!uart_avail());
    return UART_RX_DATA;
}

void uart_puthex_nibble(uint8_t nib)
{
    nib &= 0x0fU;
    if (nib < 10U) {
        uart_putc((char)('0' + nib));
    } else {
        uart_putc((char)('a' + (nib - 10U)));
    }
}

void uart_puthex8(uint8_t val)
{
    uart_puthex_nibble(val >> 4);
    uart_puthex_nibble(val & 0x0f);
}

void uart_puthex16(uint16_t val)
{
    for (int shift = 12; shift >= 0; shift -= 4) {
        uart_puthex_nibble((uint8_t)(val >> shift));
    }
}

void uart_puthex32(uint32_t val)
{
    uart_puthex16((uint16_t)(val >> 16));
    uart_puthex16((uint16_t)(val & 0xffffU));
}
