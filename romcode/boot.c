#include <stdint.h>
#include "uart.h"

void start(void)
{
    uart_puts("Hello from C\r\n");

    for (;;) {
        __asm__ volatile ("nop");
    }
}

