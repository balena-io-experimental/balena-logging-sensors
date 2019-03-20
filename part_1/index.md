
# Logging Data With Balena Pt. 1: Reading Sensors in Embedded Linux

[![Screencast](https://img.youtube.com/vi/G9E_acl3zeI/0.jpg)](https://www.youtube.com/watch?v=G9E_acl3zeI)

This project is the first in a three part series that explores in depth how to log data from sensors with embedded Linux and a container-based architecture.  You'll learn how to connect a sensor to a Linux board and read data from it, how to store and graph sensor data with modern service tools like InfluxDB and Grafana, and how to scale the application up to many devices and sensors.  This first project explores in depth how to read sensors with embedded Linux using  IIO and hwmon device drivers.

## Hardware

To follow this project you'll need the following hardware:

*   [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b-plus/).  You can use any other embedded Linux board supported by BalenaOS or Docker, but the Raspberry Pi 3 is recommended because of its low cost and vast ecosystem of peripherals like sensors.
*   [Pimoroni Enviro-pHAT](https://shop.pimoroni.com/products/enviro-phat). This is a simple add-on board for the Raspberry Pi with a collection of sensors including the BMP280 pressure & temperature sensor, an ADS1015 analog to digital converter, TCS3472 light sensor, and LSM303D accelerometer & magnetometer.

If you don't have these exact devices you can still follow along and learn the general steps to discover and use sensors in embedded Linux.

## Setup

To get started you'll need to assemble your hardware (i.e. solder any headers or connectors) and connect it to the Raspberry Pi.  For the Enviro-pHAT it's easy to slide its 26-pin connector directly on to the Raspberry Pi's GPIO header pins.

For the Pi software you'll want to install either [BalenaOS](https://www.balena.io/os/) (which includes the Balena engine for running Docker containers), or [Raspbian and Docker](https://www.raspberrypi.org/blog/docker-comes-to-raspberry-pi/_) on the Raspberry Pi.

If you're using BalenaOS you'll want to [enable local mode development](https://www.balena.io/docs/learn/develop/local-mode/) so you can access the device directly and experiment with sensor reading.  When using local mode you'll also want to [install the Balena CLI tools](https://www.balena.io/docs/reference/cli/) on your development computer to simplify accessing the device.  Be sure to familiarize yourself with the basics of [Balena device local development](https://www.balena.io/docs/learn/develop/local-mode/) before starting too.

Finally you'll want [Docker Desktop](https://www.docker.com/products/docker-desktop) installed on your development computer.  Docker will be used later in this guide to run containers locally that ease the development of sensor-related configuration files.

## Sensors and Embedded Linux

There are two major ways to interact with sensors and devices in embedded Linux:

*   The Linux kernel (or operating system) can talk to the sensor directly with a device driver.  This driver is part of the operating system code and makes it easy for any application or code to use the sensor.  Your application simply asks the kernel for a sensor reading and doesn't have to worry about how to talk to the sensor.
*   Your application can write code to talk to the sensor over an appropriate hardware bus or interface.  For example the sensors on the Enviro-pHAT use the I2C protocol to interface with the board, and you could write (or find) code that talks to the sensors directly over the I2C bus.  Pimoroni publishes a [Python library](https://github.com/pimoroni/enviro-phat) to access all of the sensors on the board from application code instead of from a driver.

Which way is the 'best' way to talk to a sensor with embedded Linux, should you let the kernel talk to it with a driver or leave it up to your application code?  The answer is, it depends!  However the first approach of using a device driver and the Linux kernel to talk to a sensor has a few advantages over your application code doing so:

*   Device driver code in the kernel has the most direct and unconstrained access to hardware.  This is important because many sensors and devices require specific timing or complex interactions that application code or a library can't guarantee.
*   Device drivers make data available to *all* programming languages and tools on the device.  With a device driver you aren't limited to a specific programming language or tool like you are with a library.
*   The kernel provides a full-featured interface for reading sensor data that can simplify your application code.  For example you can tell the kernel to sample sensor readings automatically in the background as your application runs.  The kernel can trigger events, store sensor readings in a buffer, and more without you having to write any code in your application.

This project will explore how to use Linux device drivers to read data from the BMP280 pressure/temperature and ADS1015 analog to digital converter sensors on the Enviro-pHAT.

## Reading Enviro-pHAT Temperature & Pressure

Let's learn how to read a sensor with a device driver by following step-by-step the process of enabling and reading the BMP280 pressure/temperature sensor on the Enviro-pHAT.  Following these basic steps will allow you to access any sensor supported by embedded Linux:
1.   Find the driver that supports your sensor.
2.   Verify your board's kernel includes the sensor driver.
3.   Create a device tree overlay to enable the sensor driver.
4.   Apply the sensor driver overlay to your board.
5.   Read sensor data from the driver.

One important note is that the Linux kernel is a massive and ever-evolving project.  The description and instructions below were written in 2019 and should be relevant for older and newer kernels, but be aware that information and best practices might change over time.  If the information you see does not match what's described you might need to explore on your own for more up to date best practices.

## Find The Driver That Supports Your Sensor

First you'll want to find out if the Linux kernel has a driver for your sensor.  Since the kernel is such a large piece of software with thousands of contributors there's no single document or list that's up to date with all drivers.  Instead you'll want to look through the drivers in the [kernel source code](http://www.kernel.org/) to see what's available.

For sensors there are primarily two places you should look for drivers:
*   The Industrial I/O (IIO) subsystem, this is the most recent and modern system for interfacing sensors with Linux.  You can find these drivers in the [drivers/iio directory of the kernel source code](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/iio?h=v4.14.105).
*   The hardware monitoring (hwmon) subsystem, this is an older system for interfacing common computer sensors like temperature, fan speed, etc. with Linux.  You can find these drivers in the [drivers/hwmon directory of the kernel source code](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/hwmon?h=v4.14.105).

Let's look at the IIO system to see if it has a BMP280 pressure/temperature sensor driver.  Be sure to check the version of your kernel (you can run a command like `uname -r` on the device to see it) and navigate to the right kernel version source code from [kernel.org](https://www.kernel.org/).

In this example my board is using a 4.14.x kernel and the kernel source code is [available here](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/?h=v4.14.105).  The IIO system drivers are in the [drivers/iio subfolder here](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/?h=v4.14.105).  Notice there are subdirectories like accel, adc, etc. that classify the different types of sensors.  Navigating into the [drivers/iio/pressure](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/iio/pressure?h=v4.14.105) folder shows a few files named bmp280 which seems promising.

To confirm there's a driver available for your sensor it's best to [read the KConfig file](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/iio/pressure/Kconfig?h=v4.14.105) in the driver source directory. This is a file used when building the kernel to describe the available drivers.  If you scroll through the KConfig you can see it mentions a driver for the BMP280 and other related Bosch pressure sensors:

````
config BMP280
  tristate "Bosch Sensortec BMP180/BMP280 pressure sensor I2C driver"
  depends on (I2C || SPI_MASTER)
  select REGMAP
  select BMP280_I2C if (I2C)
  select BMP280_SPI if (SPI_MASTER)
  help
    Say yes here to build support for Bosch Sensortec BMP180 and BMP280
    pressure and temperature sensors. Also supports the BME280 with
    an additional humidity sensor channel.

    To compile this driver as a module, choose M here: the core module
    will be called bmp280 and you will also get bmp280-i2c for I2C
    and/or bmp280-spi for SPI support.
````

This looks like exactly the driver necessary to support a BMP280 pressure sensor connected over the I2C bus like on the Enviro-pHAT.  Notice the driver supports other sensors like the BMP180 and BME280, and it even supports other connections like a SPI bus interface.

The important part to take away from this description is the name of the driver, specifically it mentions 'the core module will be called **bmp280**'.  If the description doesn't say it explicitly then the driver name is typically the name at the top of the config (BMP280) or even the related source file name (bmp280.c).

### Verify Your Board's Kernel Includes The Sensor Driver

Now that you've verified a driver is available, there's another important step to confirm the specific kernel your board is running actually includes that driver.  Remember the kernel is an enormous peice of software with millions of lines of source code.  It's not typically possible to compile and build in every single driver so operating systems and Linux distributions have to pick and choose which drivers they include in their build of the kernel.

You might find your board's kernel does not actually include a driver you need, even though the source code is available in the kernel.  If this happens you'll need to build a custom kernel or driver module to include the missing driver.  Building a custom kernel or driver module is outside the scope of this project, but check out the [Balena kernel module project](https://github.com/balena-io-projects/kernel-module-build) for an example of building a kernel module for a BalenaOS application.

The easiest way to check if your board supports a driver is to use the `modinfo` command on a running device.  This command searches the running kernel for all the drivers it includes and prints out a description of any that are found to match.  For example from a terminal on the host OS of a device try running:
````
modinfo bmp280
````

Notice you see output about the driver:
````
pi@raspberrypi:~ $ modinfo bmp280
filename:       /lib/modules/4.14.79-v7+/extra/pressure/bmp280.ko
license:        GPL v2
description:    Driver for Bosch Sensortec BMP180/BMP280 pressure and temperature sensor
author:         Vlad Dogaru <vlad.dogaru@intel.com>
srcversion:     CBA7D99817A6ABA1D469A37
depends:        industrialio
name:           bmp280
vermagic:       4.14.79-v7+ SMP mod_unload modversions ARMv7 p2v8
````

This confirms the kernel on the board is compiled with support for the BMP280 sensor driver.

Let's check another sensor just to see what happens when it's not compiled in or available to the running kernel.  Try the TCS3472 color sensor on the Enviro-pHAT:
````
pi@raspberrypi:~ $ modinfo tcs3472
modinfo: ERROR: Module tcs3472 not found.
````

Notice the command fails to find a module for the sensor.  This means that although the kernel has [source code for the TCS3472 available](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/iio/light/tcs3472.c?h=v4.14.105), it was *not* compiled or made available to the kernel running on the device.  Unfortunately it will not be possible to use this sensor without rebuilding the kernel or providing the driver as an externally loaded kernel module.  You can however still use a library like the Pimoroni Python code to read and interact with this sensor!

## Create A Device Tree Overlay To Enable The Sensor Driver

Once you've confirmed the Linux kernel supports your sensor you need to use the device tree to configure and enable the sensor driver.  The device tree is a concept in Linux that's simply a description of the hardware connected to a board.  Think of the device tree like a list of ingredients in a recipe.  With a recipe the list of ingredients alone isn't enough to make the dish, you also need instructions which explain how to use and combine each of the ingredients together.  The driver code in the kernel is kind of like the instructions in a recipe--it explains how to use the hardware described in the device tree. Remember the device tree describes what is connected, and the kernel code instructs how those devices work--you need both things to have a functioning Linux system!

For now we'll assume a device tree overlay is already written and move on to show how to compile and apply it to the board and enable the sensor.  However check out the [appendix to this guide](#appendix-writing-a-device-tree-overlay) for a deep dive into how to write your own device tree overlays.  The overlay we intend to use is the following [enviro-phat.dts](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/dtoverlay/overlays/enviro-phat.dts) file:
````
/dts-v1/;
/plugin/;

&i2c1 {
  status = "okay";
  #address-cells = <1>;
  #size-cells = <0>;

  /* Define the BMP280 pressure sensor at address 0x77 */
  bmp280@77 {
    compatible = "bosch,bmp280";
    reg = <0x77>;
  };

  /* Define the ADS1015 ADC at address 0x49 */
  ads1015@49 {
    compatible = "ti,ads1015";
    reg = <0x49>;
  };
};
````

## Compiling A Device Tree Overlay

Once you've written a device tree overlay source file you need to compile it into a binary that can be applied to the kernel.  The dtc device tree compiler tool makes it easy to perform this compilation.  However you'll want to make sure you're using the latest version of the compiler as some of the syntax above (like the shorthand &&lt;symbol&gt; syntax) isn't supported by older versions.  Let's use a [container called dtoverlay](https://github.com/tdicola/balena_logging_sensors_pt_1/tree/master/dtoverlay) that builds and runs the  dtc tool to ensure we use the right version.

To use this dtoverlay container you'll want to download and build its Dockerfile.  Grab the [dtoverlay container Dockerfile and its subdirectories from Github](https://github.com/tdicola/balena_logging_sensors_pt_1/tree/master/dtoverlay) and extract it to a location on your development machine (not your board).  You don't have to run this container on your board to compile overlays as the device tree format is architecture independent.

With this dtoverlay container notice it has an overlays and scripts subfolder.  The overlays folder is where you can drop device tree overlay source files.  When the container is built it will compile all the source files it finds and write them back as binary device tree overlays.  These source files should have .dts extensions, and the binary overlays will be written with a .dtbo extension.

Inside the overlays folder place your enviro-phat.dts file that was created in the previous step.  Next build the container using Docker, from a command terminal navigate to the folder with the Dockerfile and run:
````
docker build -t dtc .
````
During the container build you should see output about the dtc tool running to compile each source file in the overlays folder:
````
... container build steps omitted ...
compile_overlays: Compiling all .dts overlay sources in /overlays
Version: DTC 1.4.7
compile_overlays: Compiling /overlays/enviro-phat.dts
... container build steps omitted ...
````
If there's an error in the syntax of the device tree overlay source you'll see it fail and printed here.  

If you don't see any errors then the overlay was successfully compiled!  Compiled overlays are stored inside the /overlays folder of the container.  If you need to retrieve a compiled overlay you can mount the /overlays folder from the container to your development machine and run a command to compile the overlays again:
````
docker run -v $(pwd)/overlays:/overlays dtc compile_overlays
````
This will compile all .dts overlays in the ./overlays subfolder into binary .dtbo files.  Since the container's /overlays folder was mounted to your development machine's ./overlays folder you can simplify navigate into the overlays subfolder and retrieve the .dtbo files.

## Apply The Sensor Driver Overlay To Your Board

With a binary overlay .dtbo file you're now ready to apply it to your board's device tree.  There are two different ways to apply an overlay:

*   At boot with the board's bootloader.
*   Dynamically at runtime using experimental/in-development APIs.

When an overlay is applied at boot it will be available as soon as possible, but it is *always* applied and cannot be removed or changed without modifying the bootloader configuration and rebooting.  In addition overlays loaded at boot depend on the bootloader to configure them and unfortunately there is no standard for this configuration across different boards--configuring the overlays to boot on a Raspberry Pi is a much different process than configuring on a BeagleBone Black for example.

An alternative to loading overlays at boot is to load them dynamically at runtime.  In recent years the Linux kernel has added experimental support for applying a device tree overlay after the board has booted.  The advantage of this method is that it's much simpler and faster to experiment with hardware as adding an overlay doesn't require updating the bootloader and rebooting.  However be warned that dynamic overlay support is [known to have some problems](https://elinux.org/Frank%27s_Evolving_Overlay_Thoughts) and might not work with all hardware or overlays.  For simple scenarios like adding a sensor to a board it's worth trying dynamic overlay support as it greatly simplifies the process of loading an overlay.

Let's look at both methods for applying an overlay, dynamic and at boot.  We'll start with the easier and more universal method of loading overlays dynamically.

### Loading Overlays Dynamically

To load an overlay dynamically you can use a special configuration system in the kernel called ConfigFS.  You can see the [instructions for loading overlays with ConfigFS here](https://www.96boards.org/documentation/consumer/dragonboard/dragonboard410c/guides/dt-overlays.md.html), however as a convenience the dtoverlay container used to compile overlays can also apply overlays using ConfigFS.

Let's use the dtoverlay container to compile and apply the enviro-phat.dts source we created in previous steps.  We'll look at how to do this both with Raspbian & Docker, and BalenaOS.

#### dtoverlay Container With Docker

If you're using Docker on your device, copy over the dtoverlay container Dockerfile (including the overlays and scripts folder) to your board using a tool like scp.  Add your enviro-phat.dts source file to the overlays folder too, and make sure the dtoverlay container builds and compiles the overlay without error.  From a terminal on the device navigate to folder with the dtoverlay Dockerfile and run:
````
docker build -t dtc .
````

The dtoverlay container should be built and assigned a tag name of dtc.  Be sure the overlays are inside the container compile without error during the build!

Now use an `apply_overlays` command inside the container to apply the compiled enviro-phat overlay:
````
docker run -it --privileged dtc apply_overlays enviro-phat
````
Notice the container is run with the `--privileged` flag which is necessary to give it access to ConfigFS for applying overlays.  Also notice overlays are specified without any extension, i.e. just 'enviro-phat' instead of 'enviro-phat.dts' or 'enviro-phat.dtbo' (the container will look for compiled .dtbo files in its /overlays folder).

If everything goes well you should see the container run and print a message about appplying the overlay:
````
pi@raspberrypi:~/dtoverlay $ docker run -it --privileged dtc apply_overlays enviro-phat
apply_overlays: Applying overlay enviro-phat.dtbo
````

If there's an error then likely the overlay could not be loaded and applied--remember dynamic overlay support is still experimental and might not support all overlays.

You can check that the overlay was applied successfully and the driver for the BMP280 was loaded using the `lsmod` command to list all the running kernel modules.  After applying the overlay you should see the bmp280 driver running:
````
pi@raspberrypi:~/dtoverlay $ lsmod | grep bmp280
bmp280_i2c             16384  0
bmp280                 20480  1 bmp280_i2c
industrialio           73728  1 bmp280
````
If you don't see the bmp280 driver or any output then the overlay could not be applied, or the bmp280 driver wasn't loaded.  Typically the kernel debug log viewed with the `dmesg` command can have more information to help investigate why a driver isn't loading.

#### dtoverlay Container With BalenaOS

If you're using a BalenaOS device you can instead use the Balena engine just like Docker to run the dtoverlay container and its apply_overlays script.  Again you must ensure the container is run with the --privileged option so it has access to ConfigFS.

From your development machine navigate to the location of the dtoverlay container.  Ensure the enviro-phat.dts file you created is in the overlays subfolder of the container.  Then create a `docker-compose.yml` file to specify commands and options for running the container on the device:
````
version: '2'

services:

  dtoverlay-enviro-phat:
    build: .
    command: apply_overlays enviro-phat
    privileged: true
    restart: no
````

Notice the compose file defines a single service to build the dtoverlay Dockerfile (which will also compile all the overlay source files inside it) and run the apply_overlays command with the enviro-phat overlay.  Take note that the container is run as a privileged container, and that it will not be restarted (the container only needs to run once after boot to apply the overlay).

Push this compose file to your local mode device (adjust the IP address to that of your device as appropriate):
````
tony@tony-matebook:~/dtoverlay$ sudo balena push 192.168.1.112
[Info]    Starting build on device 192.168.1.112
[Info]    Compose file detected
[Build]   [dtoverlay-enviro-phat] Step 1/15 : FROM alpine:latest
[Build]   [dtoverlay-enviro-phat]  ---> c29735a66c89
... container build steps omitted ...
[Info]    Streaming device logs...
[Logs]    [3/6/2019, 1:23:44 PM] Installing service 'dtoverlay-enviro-phat sha256:58e90747e550e27cff8799701d879bf20ac0ec241d41148ed7f47824f56dba93'
[Logs]    [3/6/2019, 1:23:45 PM] Installed service 'dtoverlay-enviro-phat sha256:58e90747e550e27cff8799701d879bf20ac0ec241d41148ed7f47824f56dba93'
[Logs]    [3/6/2019, 1:23:45 PM] Starting service 'dtoverlay-enviro-phat sha256:58e90747e550e27cff8799701d879bf20ac0ec241d41148ed7f47824f56dba93'
[Logs]    [3/6/2019, 1:23:47 PM] Started service 'dtoverlay-enviro-phat sha256:58e90747e550e27cff8799701d879bf20ac0ec241d41148ed7f47824f56dba93'
[Logs]    [3/6/2019, 1:23:47 PM] [dtoverlay-enviro-phat] apply_overlays: Applying overlay enviro-phat.dtbo
[Logs]    [3/6/2019, 1:23:49 PM] Service exited 'dtoverlay-enviro-phat sha256:58e90747e550e27cff8799701d879bf20ac0ec241d41148ed7f47824f56dba93'
````

When the compose file is pushed to the device it will build the overlays and apply them dynamically.  Notice the device logs show the apply_overlays command loaded the enviro-phat.dtbo object.  If you connect to a host terminal on the device you can verify the bmp280 driver is running with `lsmod`:
````
tony@tony-matebook:~/dtoverlay$ sudo balena local ssh 192.168.1.112 --host
root@962db6e:~# lsmod | grep bmp280
bmp280_i2c             16384  0
bmp280                 20480  1 bmp280_i2c
industrialio           73728  1 bmp280

````

### Loading Overlays At Boot

If you run into problems with dynamically loading overlays the best alternative is to load overlays at boot from the board bootloader.  This method is a little more complex and board-specific but is the most stable and supported way to load device tree overlays.  Since each board is different you'll want to consult your board's documentation to see how it loads overlays in its bootloader.  For this example we'll assume a Raspberry Pi running either Raspbian or BalenaOS.

#### Raspbian

For background information on using device tree overlays with the Raspberry Pi be sure to consult the [official Raspberry Pi documentation on device tree overlays](https://www.raspberrypi.org/documentation/configuration/device-tree.md).  To summarize the steps you'll need to do the following:

1.   Mount the Raspbian OS SD card on your development machine and copy any compiled .dtbo overlays to the /boot/overlays directory of the SD card.

2.   Edit the /boot/config.txt file to add a line that enables the overlay:
     ````
     dtoverlay=<overlay-name-without-dtbo-extension>
     ````

For example try copying the enviro-phat.dtbo compiled earlier in a container to your card's /boot/overlays directory (remember you want the compiled .dtbo file and **not** the .dts source file).  Then add the following line to the config.txt to enable it on the next boot:
````
dtoverlay=eviro-phat
````

After booting the Pi use the `lsmod` command as mentioned previously to verify the BMP280 driver is loaded and the overlay was applied.

#### BalenaOS

With BalenaOS on a Raspberry Pi the process of enabling a device tree overlay at boot is very similar to Raspbian.  You'll mount the SD card on your development machine but instead of copying the overlay to /boot/overlays you'll copy it to /resin-boot/overlays.

Next you'll enable the dtoverlay config, but it is important to note you won't do this by modifying the config.txt in the boot folder.  BalenaOS devices manage the /boot/config.txt file themselves and won't persist or apply manual changes you make to it.  Instead you'll want to [set a device configuration variable](https://www.balena.io/docs/reference/OS/advanced/#setting-device-tree-overlays-dtoverlay-and-parameters-dtparam-) that will tell BalenaOS to update the config file appropriately.

Let's try it:

1.  Mount the BalenaOS SD card on your development machine and copy the compiled enviro-phat.dtbo object to the /resin-boot/overlays folder.

2.  Boot your device and allow it to connect to Balena cloud.

3.  In Balena cloud find your device and set a device configuration variable `RESIN_HOST_CONFIG_dtoverlay` to the value `"enviro-phat"` (note the quotes are important as this value can be a comma separate list of overlay names).
    ![](images/balena_cloud_dtoverlay_config.png?raw=true)

4.   If your device didn't reboot automatically after the configuration variable change, manually reboot it from the Balena cloud.

After the device reboots with the configuration variable and overlay applied it should adjust the config.txt automatically and apply the overlay.  Login to a host terminal on the device and confirm with `lsmod` that the BMP280 driver is loaded.

**Important Note:** Currently BalenaOS does not persist modifcations to the /resin-boot/overlays folder across OS updates.  This means if you update the BalenaOS version on the device you'll need to manually copy the enviro-phat.dtbo or other overlays back to the /resin-boot/overlays folder.

### Sensor Summary

At this point you've successfully built, compiled, and applied a device tree overlay to enable the BMP280 pressure/temperature sensor on your board!

Let's summarize the steps by enabling another sensor on the Enviro-pHAT, the ADS1015 analog to digital converter:
1.  Verify the kernel supports the ADS1015 driver.  By searching the kernel driver code and KConfig files you can see the [ADS1015 is available as an older hwmon style sensor driver](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/drivers/hwmon/Kconfig?h=v4.14.105#n1515) called 'ads1015'.

2.  Verify the kernel running on the board includes the ADS1015 driver.  Running `modinfo ads1015` on the board reports the driver is included:
    ````
    root@962db6e:~# modinfo ads1015
    filename:       /lib/modules/4.14.79/kernel/drivers/hwmon/ads1015.ko
    license:        GPL
    description:    ADS1015 driver
    author:         Dirk Eibach <eibach@gdsys.de>
    srcversion:     21ECF37F1F37A737DC58E74
    alias:          i2c:ads1115
    alias:          i2c:ads1015
    alias:          of:N*T*Cti,ads1115C*
    alias:          of:N*T*Cti,ads1115
    alias:          of:N*T*Cti,ads1015C*
    alias:          of:N*T*Cti,ads1015
    depends:        hwmon
    intree:         Y
    name:           ads1015
    vermagic:       4.14.79 SMP mod_unload modversions ARMv7 p2v8
    ````

3.  Craft a device tree fragment to enable the sensor and loads its driver.  Since this is an I2C-based sensor we know it will be added to the same `i2c1` bus parent in the device tree as the BMP280 sensor.  We can find the [device tree binding documentation for the ADS1015 driver](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/hwmon/ads1015.txt?h=v4.14.105) and see that it requires no special parametesr beyond the required `compatible` and `reg` fields.  The documentation tells us the `compatible` field should be set to `ti,ads1015`, and based on the [schematic/description of the Enviro-pHAT](https://pinout.xyz/pinout/enviro_phat) we see the `reg` value with the I2C address of the device should be `0x49`.

    With this information we can update the enviro-phat.dts source to include a new node for the ADS1015 sensor, here is the full updated file:
    ````
    /dts-v1/;
    /plugin/;

    &i2c1 {
      status = "okay";
      #address-cells = <1>;
      #size-cells = <0>;

      /* Define the BMP280 pressure sensor at address 0x77 */
      bmp280@77 {
        compatible = "bosch,bmp280";
        reg = <0x77>;
      };

      /* Define the ADS1015 ADC at address 0x49 */
      ads1015@49 {
        compatible = "ti,ads1015";
        reg = <0x49>;
      };
    };
    ````

4.  Use the dtoverlay container to compile the updated enviro-phat.dts source and verify there are no syntax errors in the overlay source.

5.  Use the dtoverlay container's apply_overlays script to apply the updated overlay to a running board (or update the board's bootloader configuration to apply the updated overlay at boot).

6.  Verify the ads1015 driver is loaded with `lsmod`:
    ````
    root@962db6e:~# lsmod | grep ads1015
    ads1015                16384  0
    hwmon                  16384  1 ads1015
    ````

Success! We've now enabled two sensors on the Enviro-pHAT as native Linux devices.  Let's continue on to see how to read data from these sensors.

## Read Sensor Data

After all the work above to enable drivers for the BMP280 and ADS1015 sensors on the Enviro-pHAT you'll be rewarded with a very simple way to read their data.

Let's start with the BMP280 sensor that uses the Industrial I/O (IIO) system.

### Read IIO Sensor

Make sure your board has the enviro-phat.dts overlay applied and you've verified the bmp280 driver is loaded as the previous sections show.  Once the bmp280 driver is running you will see a new IIO device created for it.  All of the IIO devices live under the /sys/bus/iio/devices path, and each device is created with a name like `iio:device0`, `iio:device1`, etc.  You interact with these devices by simply using the filesystem.  

From a host terminal connected to the device let's explore the BMP280 device:
````
root@962db6e:~# cd /sys/bus/iio/devices/iio\:device0
root@962db6e:/sys/bus/iio/devices/iio:device0# ls -l
total 0
-r--r--r-- 1 root root 4096 Mar  6 21:38 dev
-rw-r--r-- 1 root root 4096 Mar  6 21:38 in_pressure_input
-rw-r--r-- 1 root root 4096 Mar  6 21:38 in_pressure_oversampling_ratio
-r--r--r-- 1 root root 4096 Mar  6 21:38 in_pressure_oversampling_ratio_available
-rw-r--r-- 1 root root 4096 Mar  6 21:38 in_temp_input
-rw-r--r-- 1 root root 4096 Mar  6 21:38 in_temp_oversampling_ratio
-r--r--r-- 1 root root 4096 Mar  6 21:38 in_temp_oversampling_ratio_available
-r--r--r-- 1 root root 4096 Mar  6 21:38 name
lrwxrwxrwx 1 root root    0 Mar  6 21:38 of_node -> ../../../../../../../firmware/devicetree/base/soc/i2c@7e804000/bmp280@77
drwxr-xr-x 2 root root    0 Mar  6 21:38 power
lrwxrwxrwx 1 root root    0 Mar  6 21:38 subsystem -> ../../../../../../../bus/iio
-rw-r--r-- 1 root root 4096 Mar  6 21:32 uevent
root@962db6e:/sys/bus/iio/devices/iio:device0# cat name
bmp280
root@962db6e:/sys/bus/iio/devices/iio:device0# cat in_pressure_input
100.120191406
root@962db6e:/sys/bus/iio/devices/iio:device0# cat in_temp_input
31430
````

Notice the /sys/bus/iio/devices/iio:device0 folder which represents the sensor.  Inside the folder are a few files/nodes that you can interact with to read information and data from the sensor:

*   **name** - This file has the name of the sensor, bmp280.  It's useful to read this node if you have multiple sensors and aren't sure which one IIO has assigned to device 0, 1, etc.
*   **in\_&lt;measurement&gt;\_input** - Reading this node will return a sensor measurement the device can make.  For example reading **in_pressure_input** will read the pressure from the sensor in kilopascals, or reading **in_temp_input** will read the temperature in milli-degrees Celsius (divide this value by 1000 to get a true degrees Celsius reading).  You can learn more about the units and types of measurements that IIO exposes in the [IIO documentation here](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-iio).

This is pretty interesting if you've never used the IIO system before!  IIO is taking care of all the hard work of talking to the sensor, getting measurements, and converting those measurements to standard units like Pascals of pressure or degrees Celsius.  The power of IIO is that *all* sensors will represent themselves in the same way as nodes in the filesystem.  Your application code in any programming langauge or script can simply read from these nodes to take a new reading!

This is only scratching the surface of what's possible with IIO sensors.  IIO has more advanced capabilities like reading sensors at high speed and storing the data in a buffer (thus freeing your application code to do other tasks).  You can learn more about IIO from some of these resources:

*   [IIO System Overview Wiki](https://wiki.analog.com/software/linux/docs/iio/iio) - This is a good general starting point for links to more IIO information and resources.
*   [libiio Wiki](https://wiki.analog.com/resources/tools-software/linux-software/libiio) - libiio is a library that simplifies accessing IIO device data.  You can use libiio to unlock and make use of many of IIO's advanced capabilities like high speed sampling.
*   [libiio - Access to Sensor Devices Made Easy talk by Lars-Peter Clausen](https://www.youtube.com/watch?v=CS9NuRBzN5Y) - This is an overview of libiio and IIO device usage.
*   [Industrial I/O and You: Nonsense Hacks! talk by Matt Ranostay](https://www.youtube.com/watch?v=lBU77crSvcI) - This is another great overview presentation which demonstrates simple and advanced usage of IIO devices.

### Read hwmon Sensor

Let's read data from the ADS1015 analog to digital converter to demonstrate reading sensor data from an older hardware monitoring (hwmon) system.  Remember when we enabled the ADS1015 device we saw it was a part of the hwmon system and not the IIO system.  Reading data from hwmon sensors is very similar to with IIO, you just need to use a slightly different path to access the device and its data.

From a host terminal connected to the device let's explore the ADS1015 device:
````
root@962db6e:~# cd /sys/class/hwmon/hwmon0/device
root@962db6e:/sys/class/hwmon/hwmon0/device# ls -l
total 0
lrwxrwxrwx 1 root root    0 Mar  6 22:01 driver -> ../../../../../../bus/i2c/drivers/ads1015
drwxr-xr-x 3 root root    0 Mar  6 21:32 hwmon
-r--r--r-- 1 root root 4096 Mar  6 22:01 in0_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in1_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in2_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in3_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in4_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in5_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in6_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 in7_input
-r--r--r-- 1 root root 4096 Mar  6 22:01 modalias
-r--r--r-- 1 root root 4096 Mar  6 22:01 name
lrwxrwxrwx 1 root root    0 Mar  6 22:01 of_node -> ../../../../../../firmware/devicetree/base/soc/i2c@7e804000/ads1015@49
drwxr-xr-x 2 root root    0 Mar  6 22:01 power
lrwxrwxrwx 1 root root    0 Mar  6 21:32 subsystem -> ../../../../../../bus/i2c
-rw-r--r-- 1 root root 4096 Mar  6 21:32 uevent
root@962db6e:/sys/class/hwmon/hwmon0/device# cat name
ads1015
root@962db6e:/sys/class/hwmon/hwmon0/device# cat in0_input
0
root@962db6e:/sys/class/hwmon/hwmon0/device# cat in4_input
274
````
The path to a hwmon device is slightly different than an IIO device, notice it's under the /sys/class/hwmon/hwmon\*/device path (where the * is a number assigned to the sensor like 0, 1, etc.).  Inside this location you'll see similar files to read data from the device:
*   **name** - Like an IIO device this node has the name of the device, in this case ads1015 for the sensor we're reading.
*   **in\*\_input** - These nodes are numbered based on ADC voltage measurement channels exposed by the driver.  If you go back to the [ADS1015 binding documentation](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/hwmon/ads1015.txt?h=v4.14.105) you can see it mentions that channel 0 through 3 are for differential readings (i.e. the voltage between two channels) and channels 4 through 7 are for single-ended readings (i.e. the voltage between a channel and ground).  With hwmon devices they expose ADC values as voltages in millivolts.  In the example above **in0_input** is reading a value of 0mV in differential mode between channel 0 and 1, and **in4_input** is reading 274mV from channel 0 to ground.  See the [hwmon documentation](https://www.kernel.org/doc/Documentation/hwmon/sysfs-interface) for more details on the units and names of other device measurements the system supports.

It is increasingly uncommon to find sensors that only support this older hwmon interface.  New sensors are instead added to the IIO system and only older, legacy sensors that haven't yet been migrated still live in hwmon.

## Summary

This project has shown how to enable sensor device drivers that talk to hardware with embedded Linux.  You saw the steps to find drivers, create device tree overlays, and apply those overlays to a board.  Using these steps you can enable *any* new driver or hardware on an embedded Linux board!

In the next part of this project we'll build on reading sensor data from the Enviro-pHAT with drivers to show how to log and graph the data in a web dashboard!

## Appendix: Writing a Device Tree Overlay

In this section let's examine in detail how to approach writing a sensor device tree overlay from scratch.  Although the device tree is critical to the functioning of a Linux board it has unfortunately been a somewhat maligned and misunderstood component.  One problem is that the device tree and its usage has been under active development and much of the tools, documentation, and best practices have been evolving and changing.  Be careful to make sure information you seek out on the device tree is current and relevant to your needs.

Another common stumbling block with understanding the device tree is that there are different users of it with slightly different needs:

*   Board creators need to create entire device trees from scratch which explain in detail the hardware necessary to boot a board.  For example components like the processors, memory chips & DMA controllers, GPIO and bus controllers, etc. must be described in a device tree for any Linux board.  Typically a board creator will carefully study their processor and hardware datasheets to exactly describe the registers, memory addresses, etc. in their device tree.  For them the hardware is fixed and never changes between board reboots.
*   Board users however just need to create small additions, or overlays, to their board's device tree that enable new hardware.  Rather than write an entirely new device tree from scratch, these users just need to add a small sensor or piece of hardware to an existing device tree.  In this case the hardware can be dynamic and change between boot when a sensor is added or removed.

Keep these two users in mind as you explore and learn more about the device tree.  Much of the information and documentation available on the device tree is targeted at board creators who expect to create and interact with entire device trees that never change.  If you're a board user that just needs to add a sensor or small device to a board then you don't need to fully immerse yourself in all the quirks and functions of the device tree.  This project will point you towards just enough device tree information to start adding components like sensors to your board.

For reference, as of 2019, some of the best sources of information on the device tree are:

*   [Device Tree Usage wiki](https://elinux.org/Device_Tree_Usage) - This is the most in depth and canonical reference for the device tree available today.  Be warned that this wiki dives deep into all uses of the device tree, in particular for board creators.  This is a great resource to use as a reference or to explore device tree topics in depth.
*   [Introductory device tree talks & papers](https://elinux.org/Device_Tree_presentations_papers_articles#introduction_to_device_tree.2C_overviews.2C_and_howtos) - This section of the device tree usage wiki is an amazing catalog of presentations and information on the device tree.  Start here for great introductory information, but again be aware that older presentations might not show all the latest best practices.
*   [Device Tree for Dummies talk  by Thomas Petazzoni from ELC 2014](https://www.youtube.com/watch?v=uzBwHFjJ0vU) - If you only have time to look at one resource on the device tree, be sure to watch this introductory talk from the embedded Linux conference.  This presentation explains just enough information to get started with reading and understanding device tree source code.

With that background out of the way, let's dive in and create a device tree overlay to add support for the BMP280 sensor.  When adding a new device to your board with the device tree there are two important pieces of information to find:
*   Where to add the hardware to your board's device tree.  The device tree is almost like your board's filesystem in that it has a root node and many children (with children of their own) below it.  When you add a new device with an overlay you need to find where in the device tree to put it--like under the root as a new top-level item, or maybe under a bus like the I2C or SPI bus.
*   What to put in the device tree node you're adding to the board.  This is information like the address of the device on the I2C bus or related GPIO lines like chip select, etc.  The exact information you need to specify depends on the device driver.

We'll start by answering the question of where to put a new sensor node in the device tree.  To do this we'll need to explore symbols in your board's device tree.

### Device Tree Symbols

To find out where in the device tree to place a new node it's helpful to see the entire device tree for your board.  You can use a dtc (device tree compiler) tool to print out the source for your running board's device tree.  

On a BalenaOS device you can run this dtc tool in a privileged container as a quick one-off exercise.  For example connect to the BalenaOS device host terminal and run the following command to start a Debian-based container shell:
````
balena run -it --privileged balenalib/armv7hf-debian:stretch /bin/bash
````

If you're instead running Raspbian or a similar Debian-based OS you can skip the above and connect directly to the device's shell.

Next update the OS packages and ensure the device-tree-compiler package is installed:
````
sudo apt-get update
sudo apt-get install device-tree-compiler less -y
````

Now use the dtc tool to print out the entire device tree source for the running board:
````
dtc -I fs -O dts /proc/device-treee | less
````

You can scroll through the output and the source for your board's device tree (or you can instead send the output to a file and view in an editor by replacing the pipe to less, `| less`, with a direction to a file `> board.dts`).

There's a *lot* of information in the device tree, but luckily you don't need to use or interact with all of it.  There's one important section to find, it's a symbol list that starts with `__symbols__`:
````
__symbols__ {
    uart0_gpio14 = "/soc/gpio@7e200000/uart0_gpio14";
    pwm = "/soc/pwm@7e20c000";
    gpclk1_gpio5 = "/soc/gpio@7e200000/gpclk1_gpio5";
    clk_usb = "/clocks/clock@4";
    pixelvalve0 = "/soc/pixelvalve@7e206000";
    uart0_ctsrts_gpio30 = "/soc/gpio@7e200000/uart0_ctsrts_gpio30";
    uart1_ctsrts_gpio16 = "/soc/gpio@7e200000/uart1_ctsrts_gpio16";
    uart0_gpio32 = "/soc/gpio@7e200000/uart0_gpio32";
    intc = "/soc/interrupt-controller@7e00b200";
    spi2 = "/soc/spi@7e2150c0";
    jtag_gpio4 = "/soc/gpio@7e200000/jtag_gpio4";
    dsi1 = "/soc/dsi@7e700000";
    clocks = "/soc/cprman@7e101000";
    i2c1 = "/soc/i2c@7e804000";
    i2c_vc = "/soc/i2c@7e205000";
    firmwarekms = "/soc/firmwarekms@7e600000";
    smi = "/soc/smi@7e600000";
    ... more symbols ommitted ...
};
````
Think of the symbols that a board device tree exposes as the 'extension points' or parent nodes where you can place new elements.  Symbols are simply names given to paths in the device tree, like the name `i2c1` points to the path `/soc/i2c@7e804000`. Typically a board creator will create and label symbols for all the important buses and devices on the board, and device tree overlays you create can target those symbols to place new nodes inside.

Although there's no formal convention across boards, typically you'll see symbols like:
*   `i2c*` - Where the `*` is a board's I2C bus, like on the Raspberry Pi 3 the `/dev/i2c-1` bus exposed by the GPIO header is the `i2c1` symbol.  You might notice other I2C buses in the Pi device tree symbols and wonder where those are used, they're actually internal I2C buses used by the video core processor, CPU, etc.
*   `spidev*` - Where the `*` is a board's SPI bus, like on the Raspberry Pi 3 the `/dev/spidev0.0` bus exposed by the GPIO header is the `spidev0` symbol.
*   `soc` - This is typically the root or top-most node of the device tree for modern ARM-based Linux boards.  This can be a good place to put child items which aren't associated with a bus or other device, for example if adding a sensor that only interfaces with GPIO.
*   `gpio` - This is typically the GPIO controller on the board and is a parent for much of the board's GPIO pin configuration and control.

Since the BMP280 sensor on the Enviro-pHAT is connected to the Pi's GPIO header it will be connected to the `/dev/i2c-1` bus and associated with the `i2c1` symbol as its parent in the device tree.

### Device Tree Bindings

Once you know the location to place a new device tree node you need to next understand what to put in that node.  This is called a device tree 'binding' because it associates configuration and other information with a device tree node that drivers will read to configure the device.  Device tree bindings  have their own documentation in the Linux kernel under the [Documentation/device-tree/bindings](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings?h=v4.14.105) path.  If you explore the IIO subfolders (remember the BMP280 device we're adding is using an IIO driver) you'll see it has a file [bmp085.txt](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/iio/pressure/bmp085.txt?h=v4.14.105) for the Bosch BMP pressure sensors:
````
BMP085/BMP18x/BMP28x digital pressure sensors

Required properties:
- compatible: must be one of:
  "bosch,bmp085"
  "bosch,bmp180"
  "bosch,bmp280"
  "bosch,bme280"

Optional properties:
- chip-id: configurable chip id for non-default chip revisions
- temp-measurement-period: temperature measurement period (milliseconds)
- default-oversampling: default oversampling value to be used at startup,
  value range is 0-3 with rising sensitivity.
- interrupt-parent: should be the phandle for the interrupt controller
- interrupts: interrupt mapping for IRQ
- reset-gpios: a GPIO line handling reset of the sensor: as the line is
  active low, it should be marked GPIO_ACTIVE_LOW (see gpio/gpio.txt)
- vddd-supply: digital voltage regulator (see regulator/regulator.txt)
- vdda-supply: analog voltage regulator (see regulator/regulator.txt)

Example:

pressure@77 {
  compatible = "bosch,bmp085";
  reg = <0x77>;
  chip-id = <10>;
  temp-measurement-period = <100>;
  default-oversampling = <2>;
  interrupt-parent = <&gpio0>;
  interrupts = <25 IRQ_TYPE_EDGE_RISING>;
  reset-gpios = <&gpio0 26 GPIO_ACTIVE_LOW>;
  vddd-supply = <&foo>;
  vdda-supply = <&bar>;
};
````
This is excellent information that tells you exactly what to put in a device tree node to enable the device. Nodes in the device tree typically have required and optional values.  One required value is the `compatible` field which tells the kernel exactly what driver to load for this device.  Notice the BMP sensor documentation calls out a list of possible values like "bosch,bmp280".  Take note of these values and choose the appropriate one for your device, you will need to specify it *exactly* as shown in the documentation.

You can examine the optional properties to see other parameters which allow you to adjust the behavior of the device and driver.  Typically configuration like interrupt lines, samping rate, range, etc. are specified in optional properties.

One thing this binding document doesn't make clear is that there is another required property, the `reg` field.  This field is used with I2C devices to specify the address of the device on the I2C bus.  Remember the I2C protocol allows multiple devices to be connected to the same bus and each is identified by a unique 7-bit address.  For the BMP280 sensor used on the Enviro-pHAT its [datasheet](https://ae-bst.resource.bosch.com/media/_tech/media/datasheets/BST-BMP280-DS001.pdf) mentions the device has an I2C address of 0x76 or 0x77 depending on its SDO pin value.  Pimoroni [publishes the schematic and details of their board](https://pinout.xyz/pinout/enviro_phat) so you can see definitively that its BMP280 sensor should be at I2C address 0x77.

Now we have exactly what's necessary to create a device tree overlay that tells the Linux kernel about the sensor connected to the board.  Specifically we know this important information:

*   The sensor is connected to the `/dev/i2c-1` bus (the GPIO header on the Pi) and should be a child of the `i2c1` symbol in the device tree.
*   The sensor device tree binding uses a `compatible` field value of `bosch,bmp280` to specify the BMP280 sensor.
*   The sensor is located at I2C address `0x77` on the bus and should have a `reg` value of `0x77` in the device tree binding.
*   The sensor device tree bindings support optional parameters to control measurement period, oversampling, etc.  The default values will be used to keep this example simple.

### Crafting A Device Tree Overlay

Now that we know all the information about the sensor, let's create a device tree overlay to add it to the board's device tree!  Device trees are written in a text-based language that has some similarities with the C programming language.  These source files are compiled into a compact binary form using the dtc device tree compiler tool and then applied to the board's device tree.

Create a text file called `enviro-phat.dts` and place this device tree source code inside it:
````
/dts-v1/;
/plugin/;

&i2c1 {
  /* This is boilerplate to ensure the I2C bus is enabled and the new devices
     are specified with their 8-bit I2C address in the reg property.
  */
  status = "okay";
  #address-cells = <1>;
  #size-cells = <0>;

  /* Define the BMP280 pressure sensor at address 0x77 */
  bmp280@77 {
    compatible = "bosch,bmp280";
    reg = <0x77>;

    /* Note there are optional parameters to control the sample rate and
       other state of the BMP280 sensor.  See the documentation here:
       https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/iio/pressure/bmp085.txt?h=v4.14.104
    */
  };
};
````

Let's walk through the components of this device tree overlay step by step.  The first two lines are boilerplate that describe this device tree source as an overlay using the latest v1 version of the format:
````
/dts-v1/;
/plugin/;
````

Next a block is created to target the `i2c1` symbol and add new children or update properties of it:
````
&i2c1 {
````

If you've used the device tree before you might be wondering what this syntax means--it's actually a recent addition (as of ~September 2018) to device tree source which removes older more verbose fragment syntax with a direct shorthand reference.  The ampersand and symbol name starting this block means that the properties and children within should be applied to the `i2c1` symbol in the board's device tree.

Inside the block you'll first see a comment (notice comments follow the C langauge style with `/* ... */` blocks) and three properties of the `i2c1` node that are updated:
````
status = "okay";
#address-cells = <1>;
#size-cells = <0>;
````

These properties are effectively boilerplate that all I2C bus overlays will specify.  The [documentation for I2C controller device tree bindings](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/i2c/i2c.txt?h=v4.14.105) specify their exact meaning. The status "okay" means the I2C bus should be enabled, and address-cells and size-cells are configured for a single 7-bit address in the `reg` property of child nodes.  It's not important to understand these properties in depth as they are boilerplate code necessary for targeting new devices on an I2C bus.

Now the most important part of the overlay is specified, the new node to add which describes the BMP280 sensor:
````
/* Define the BMP280 pressure sensor at address 0x77 */
bmp280@77 {
  compatible = "bosch,bmp280";
  reg = <0x77>;

  /* Note there are optional parameters to control the sample rate and
   other state of the BMP280 sensor.  See the documentation here:
   https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/devicetree/bindings/iio/pressure/bmp085.txt?h=v4.14.104
  */
};
````

The first line gives this node a name in the device tree.  The name can be any value, but typically the convention for I2C devices is to use a description of the device, `@`, and then the I2C address of the device.  This ensures that every device on an I2C bus has a unique name and path in the device tree (otherwise sensors might clash and overwrite each others configuration!).

Next notice the `compatible` and `reg` properties are specified.  These are the values discovered earlier by reading the device tree binding documentation and sensor datasheet.  The `compatible` field describes what driver to associate with this device tree node, and the `reg` property is used in I2C devices to specify the address on the I2C bus.

That's all there is to a basic device tree overlay that adds a new node!  Simply target a parent symbol in a block, specify any properties to change on that parent, and then specify new child devices to add.
