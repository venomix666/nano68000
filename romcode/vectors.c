#include <stdint.h>

extern void start(void);
extern void bus_error_entry(void);

#define INITIAL_SSP 0x00800000UL

__attribute__((section(".vectors"), used))
const uint32_t vectors[] = {
    INITIAL_SSP,                  /* Vector 0: Initial SSP */
    (uint32_t)start,              /* Vector 1: Initial PC (Reset) */
    (uint32_t)bus_error_entry,  /* Vector 2: Bus Error */
};
