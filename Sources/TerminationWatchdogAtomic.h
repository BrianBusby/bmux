#ifndef BMUX_TERMINATION_WATCHDOG_ATOMIC_H
#define BMUX_TERMINATION_WATCHDOG_ATOMIC_H

#include <stdbool.h>
#include <stdatomic.h>

typedef struct {
    atomic_bool isArmed;
} BMUXTerminationWatchdogLatch;

BMUXTerminationWatchdogLatch BMUXTerminationWatchdogLatchMake(void);
bool BMUXTerminationWatchdogLatchClaim(BMUXTerminationWatchdogLatch *latch);

#endif
