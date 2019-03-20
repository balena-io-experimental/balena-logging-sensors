#!/bin/bash
# IIO-based BMP280 pressure/temperature sensor collection script.
set -eu

# Configuration:
IIO_DEVICE=/sys/bus/iio/devices/iio:device0     # IIO device path
MEASUREMENT=bmp280_sensor                       # Measurement name to store
                                                # in InfluxDB database.

cd $IIO_DEVICE
echo $MEASUREMENT pressure=$(cat in_pressure_input),temperature=$(cat in_temp_input)
