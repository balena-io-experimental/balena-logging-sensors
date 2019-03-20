#!/bin/sh
# Container init script that can perform some basic tasks before running
# a service in the container:
#  - Execute the service only on devices which are listed in a RUN_ON_DEVICES
#    environment variable.  This variable should be set to the Balena device
#    name (as listed in Balena Cloud, not the hostname!).  This is useful to
#    run a service only a subset of devices in an app.
#  - Materialize any configuration files in the container from environment
#    variable values with the GEN_CONFIGS variable.  This is a list of tuples:
#    <env variable name>:<file to create with env variable value>
#    For example:
#    GEN_CONFIGS=FOO:/etc/foo BAR:/etc/bar
#    Will take the value of FOO and place it in /etc/foo, and the value of BAR
#    and place it in /etc/bar.
set -e

# Generate configs.
if [ -n "$GEN_CONFIGS" ]; then

  for i in $GEN_CONFIGS; do
    # Split based on a semicolon to identify the environment variable
    # and file path.
    CONFIG_VAR=`echo "$i" | cut -d':' -f1`
    CONFIG_FILE=`echo "$i" | cut -d':' -f2`
    # Skip this value if it couldn't be parsed.
    if [ -z $CONFIG_VAR -o -z $CONFIG_FILE ]; then
      echo "balena-entrypoint.sh: Failed to parse config variable and file from '$i'"
      continue
    fi
    # Check the variable has a value and fail if not set.
    eval "CONFIG_VALUE=\$$CONFIG_VAR"
    if [ -z "$CONFIG_VALUE" ]; then
      echo "balena-entrypoint.sh: Expected $CONFIG_VAR to have a value!"
      exit 1
    fi
    # Create any parent directories and set the value of the config file
    # to the config value read from the config environment variable.
    echo "balena-entrypoint.sh: Writing value of $CONFIG_VAR to file $CONFIG_FILE"
    mkdir -p $(dirname $CONFIG_FILE)
    echo "$CONFIG_VALUE" > $CONFIG_FILE
  done

fi

# Check if RUN_ON_DEVICES is set and verify this device is in the list
# before running the service.  The value of RUN_ON_DEVICES can be a space
# separated list of device names that should run this service.
# If RUN_ON_DEVICES is not set then this service will run no matter what.
if [ -n "$RUN_ON_DEVICES" ]; then

  # Loop through all the values in RUN_ON_DEVICE and check if they match this
  # device.  When a match is found run the passed in executable.
  for i in $RUN_ON_DEVICES; do
    if [ $BALENA_DEVICE_NAME_AT_INIT = $i ]; then
      echo "balena-entrypoint.sh: Running '$@' on device $BALENA_DEVICE_NAME_AT_INIT"
      exec "$@"
      exit 0
    fi
  done

  # No match was found, note it but don't fail since this is expected on devices
  # which don't match.
  echo "balena-entrypoint.sh: Skipping service, device $BALENA_DEVICE_NAME_AT_INIT does not match in 'RUN_ON_DEVICES=$RUN_ON_DEVICES'"
  exit 0
else
  # Run on devices isn't set so just run the passed in command.
  echo "balena-entrypoint.sh: Running '$@' because no RUN_ON_DEVICES variable is set."
  exec "$@"
fi
