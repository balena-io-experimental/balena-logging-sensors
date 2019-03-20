#!/bin/bash
# hwmon-based ADS1015 analog to digital converter temp/humidity sensor collection script.
set -eu

# Configuration:
HWMON_DEVICE=/sys/class/hwmon/hwmon0/device     # hwmon device path
MEASUREMENT=ads1015_sensor                      # Measurement name to store
                                                # in InfluxDB database.

cd $HWMON_DEVICE
echo $MEASUREMENT channel0=$(cat in4_input),channel1=$(cat in5_input),channel2=$(cat in6_input),channel3=$(cat in7_input)
