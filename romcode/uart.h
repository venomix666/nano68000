#ifndef UART_H
#define UART_H

#include <stdint.h>

void uart_putc(char c);
void uart_puts(const char *s);
void uart_puthex_nibble(uint8_t nib);
void uart_puthex16(uint16_t val);
void uart_puthex32(uint32_t val);

#endif /* UART_H */
