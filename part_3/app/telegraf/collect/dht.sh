#!/bin/bash
# IIO-based DHT temp/humidity sensor collection script.

# Configuration:
IIO_DEVICE=/sys/bus/iio/devices/iio:device0     # IIO device path
MEASUREMENT=dht_sensor                          # Measurement name to store
                                                # in InfluxDB database.

# Make a function to retry reads a few times as the DHT kernel driver only
# makes a best effort at reading data and might fail or miss readings.
function cat_retry() {
  for i in 1 2 3 4 5; do
    cat $1 2>/dev/null && break
  done
}

cd $IIO_DEVICE
echo $MEASUREMENT humidity=$(cat_retry in_humidityrelative_input),temperature=$(cat_retry in_temp_input)
