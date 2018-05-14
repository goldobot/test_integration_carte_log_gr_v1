#ifndef __ROBOT_SLEEP_H
#define __ROBOT_SLEEP_H

/* sleep (approx) given duration in ms

   @param[in] time_ms = duration in ms */
#define sleep(time_ms) usleep( 1000*(time_ms) )

/* sleep (approx) given duration in us

   @param[in] time_us = duration in us */
void usleep ( unsigned int time_us );

#endif
