#include <stdint.h>
#include "uart.h"

extern void monitor_run(void);

void start(void)
{
    monitor_run();
}

