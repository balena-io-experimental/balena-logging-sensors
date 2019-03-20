# Logging Data With Balena Pt. 2: Build a Sensor Dashboard

[![Screencast](https://img.youtube.com/vi/X_ECoklE3-s/0.jpg)](https://www.youtube.com/watch?v=X_ECoklE3-s)

This is the second in a three part series that dives into logging sensor data with embedded Linux, containers, and Balena's platform.  The [first part](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/index.md) was a deep dive into how sensors can be read by embedded Linux.  This second part builds on the first part to add a database and web dashboard for viewing sensor data.  You'll learn about multi-container applications in Balena and how to use services like Telegraf, InfluxDB, and Grafana to store and visualize sensor readings.

# Hardware and Setup

For this project you'll need the exact same hardware and setup as [from the previous project](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/index.md) in the series:
*   [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b-plus/).
*   [Pimoroni Enviro-pHAT](https://shop.pimoroni.com/products/enviro-phat).

Be sure to [follow part 1](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/index.md) to create and apply device tree overlays that enable the BMP280 pressure/temperature and ADS1015 analog to digital converter sensors before continuing further.

# Balena Cloud Setup

For this project you'll use [Balena Cloud](https://www.balena.io/cloud/) to create an application and deploy it to your board.  Balena Cloud is a platform that simplifies and manages the deployment of containers to embedded Linux hardware.  You just need to write the code and configuration for your containers and Balena Cloud will take care of all the infrastructure to run those containers on your hardware.

Before you start it will be helpful to familiarize yourself with Balena's platform by reviewing:
*   [Balena Primer](https://www.balena.io/docs/learn/welcome/primer/) - This is a great high level overview of the pieces that make up Balena's platform.
*   [Balena Get Started with Raspberry Pi 3 and Node.js](https://www.balena.io/docs/learn/getting-started/raspberrypi3/nodejs/) - Skim this guide to learn about the general flow for creating and pushing code to a Balena application.  We'll walk through the same steps to deploy an application in this project.

Be sure to also [setup an account and SSH key on Balena Cloud](https://www.balena.io/docs/learn/getting-started/raspberrypi3/nodejs/#account-setup) before continuing further.

# Create an Application

To start you'll need to create a new application in Balena Cloud.  Choose the 'Starter' application type and the appropriate board type for your hardware.  Assign the application a descriptive name like 'balena-datalogging':
![](images/balena_create_application.png?raw=true)

# Add Device to Application

After you've created an application you'll need to [add your device](https://www.balena.io/docs/learn/getting-started/raspberrypi3/nodejs/#add-your-first-device) to it.  Click the Add Device button in the application and pick the appropriate board type, then fill in any details like WiFi network credentials if you'd like to have it automatically connect to your network:
![](images/balena_add_device.png?raw=true)

Download the OS image for the device and load it to a SD card using [Etcher](https://www.balena.io/etcher/).

Note that if you need to setup special networking configuration for the device, like assigning it a static IP address, be sure to do so after Etcher burns the image to the card and before booting it for the first time as the [Balena networking guide](https://www.balena.io/docs/reference/OS/network/2.x/) shows.

Once the image is written to the SD card and configured you can unmount it from your computer and boot your device with it. After the device boots and connects to the Internet you should see it come online in your application dashboard on Balena Cloud.  If you click the device name (a randomly generated pair of words) you can bring up details about it and change the name to something more descriptive like 'datalogger-pi3':
![](images/balena_device.png?raw=true)

# Configure Environment Variables

For the application in this project there are a few global (or fleet-wide) environment variables you need to set in your application dashboard.  These variables will be set in all of the containers that run the application and provide a great place for global configuration settings.

The containers in this application also use these environment variables to store a few 'secrets' like password values.  With container-based applications you must take care with how you store and use secret values like passwords.  If you store those values inside a container's image (like setting them in a Dockerfile) you could risk someone accessing the secret values if the image is accidentally pushed to a public repository.  Using environment variables to store secret values is a best practice for modern container-based applications.

Back in the application dashboard (not the device information) click the E(x) Environment Variables button on the left:
![](images/balena_environment_vars_button.png?raw=true)

You'll want to add the following variables to the application.  Make sure to set their name *exactly* as shown:
*   **INFLUXDB_ADMIN_USER** - Set this to username that will be created as an admin user in InfluxDB.  A value of **admin** is typically specified.
*   **INFLUXDB_ADMIN_PASSWORD** - Set this to the password for the InfluxDB admin user.  Pick a good, strong password value.  You won't need to remember or enter this password unless you manually connect to the InfluxDB instance.
*   **INFLUXDB_DB** - Set this to the name of a database that InfluxDB will provision for storing sensor data.  A value of **telegraf** is common for setting up a datalogging stack as shown in this project.
*   **INFLUXDB_USER** - Set this to the name of a user that will be used to access the database above.  You can use the same name as the database, **telegraf**.
*   **INFLUXDB_PASSWORD** - Set this to the password for the user with access to the database above.  Again set this to a good, strong password.  You won't need to remember or enter this password unless you manually connect to the InfluxDB instance.

Make sure your environment variables are set before continuing further:
![](images/balena_environment_vars.png?raw=true)

# Push Application Code

With your application created and a device connected to it you're now ready to push containers and code to it.  Balena's platform uses a git repository to simplify the process of deploying code to a device.  With a simple `git push` command you'll have an entire stack of containers up and running with ease.

For this project you'll want to clone the application code from its [home on Github](https://github.com/tdicola/balena_logging_sensors_pt_2), i.e. in a terminal run:
````
git clone https://github.com/tdicola/balena_logging_sensors_pt_2.git
````

After cloning the code you can see it includes an `app` subfolder with a `docker-compose.yml` and other files.  The `docker-compose.yml` identifies this as a [multi-container application](https://www.balena.io/docs/learn/develop/multicontainer/) which means it's made up of a few containers that run together on the device to power the application.  We'll step through each of the containers later in the project to understand how they work, for now we'll deploy them to the hardware to see how they work.

To deploy code to a Balena application you need to add a git remote that points at Balena's build infrastructure.  This remote repository won't actually store your code (you can still use Github or any other source code host for that), instead it will receive your code and push it out to the devices in an application.  To do this you'll need to go to the application dashboard and copy the git remote command in the upper right corner:
![](images/balena_git_remote.png?raw=true)

This command will add a remote to a git repository so that code can be pushed to Balena's build system.  In a terminal navigate inside the `app` directory with the `docker-compose.yml` file and run the following command to initialize it as a git repository:
````
git init
````

Then run the git remote command you copied from the application dashboard, it will look something like this:
````
git remote add balena <your account>@git.balena-cloud.com:<your account>/balena-datalogging-pt-2.git
````

Since this is now a git repository you'll need to make sure the files are committed before they can be pushed to balena's remote repository.  This is just like working with code on Github, you must add and commit code for it to be saved.  Run these commands to commit the code:
````
git add --all
git commit -m "Initial commit"
````

Now to deploy the application code you simply push the git repository to the balena remote:
````
git push balena master
````

When you push to the balena remote you'll see quite a few things start to happen.  The code is pushed to Balena's servers and sent to build machines which build all of the containers defined in the application.  If the containers are built successfully then they'll be sent down to the running devices automatically.  A successful build will finish with information about the deployed containers and a happy unicorn:
![](images/balena_git_push.png?raw=true)

If a container fails to build you'll see the build process stop and any encountered errors are printed.  You can fix the container code, commit the changes to the git repository, and push them again to the balena remote to try again.

After successfully pushing code to Balena's servers go to the device page in your application and notice there's a new list of deployed services:
![](images/balena_device_services.png?raw=true)

You'll see each service download its new container image and start running.  After some time all of the services should be running, except for a dtoverlay service that is only designed to run once and exit.

At this point the application containers are deployed to your device and running!  Let's dive in to explore the dashboard the application services create.

# Sensor Dashboard with the TIG Stack

The containers in this project make up what's called the TIG stack. Telegraf, InfluxDB, and Grafana (TIG) are services in the TIG stack that allow an application to collect, store, and graph measurements like sensor readings:
*   [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) is an open source data and measurement collection agent.  This project uses telegraf to collect sensor readings and store them in InfluxDB.
*   [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) is an open source database designed to store time-series data like sensor measurements.  InfluxDB is used in this project to store all the sensor readings collected by telegraf.
*   [Grafana](https://grafana.com/) is an open source dashboard for visualizing data stored in many different sources, including InfluxDB.  This project uses Grafana to build dashboards that visualize sensor data store in InfluxDB.

The containers in this project are automatically configured to install and setup the TIG stack to collect data from the BMP280 and ADS1015 sensors on the Enviro-pHAT.  

Let's dive in with a quick tour of the Grafana dashboard.  You can access the dashboard on port 80 (the default web port) of your application device.  Find your device's IP address from the application dashboard and navigate to it in a web browser.  For example if you device has an IP address of 192.168.1.112 you would navigate to http://192.168.1.112/.  You should see Grafana load with a login prompt:
![](images/balena_grafana_login.png?raw=true)

The very first time you login to Grafana you must use the username **admin** and password **admin** (note this is *not* the same username and password as you set in the application environment variables, it's a default user/password Grafana sets itself).  After you login you'll be asked to change the admin user password--set the password to a strong value that you'll remember as you must use it each time you log in to the Grafana dashboard in the future.

Once you login you'll see a home screen and the option to create a new dashboard is highlighted:
![](images/balena_grafana_new_dash.png?raw=true)

Click the New Dashboard button to start creating a dashboard.  Grafana will create a new empty dashboard and add a new panel to configure.  Click the Add Query button to configure the panel:
![](images/balena_grafana_new_panel.png?raw=true)

You can specify a query that will be made against InfluxDB to retrieve sensor measurements.  Grafana has many advanced capabilities like a [visual query builder](http://docs.grafana.org/features/datasources/influxdb/#query-editor) which you can explore in depth on your own.  For now we'll add a pre-made query ourselves.

To set the query first change the **Queries to** drop-down from **default** to **InfluxDB - Telegraf**.  This tells the panel to query the InfluxDB database that was created to store sensor readings.  Then click the pencil icon on the right to toggle text edit mode and enter the following query:
````
SELECT pressure, temperature/1000 FROM bmp280_sensor;
````
![](images/balena_grafana_query.png?raw=true)

This query is made using the [InfluxDB query language](https://docs.influxdata.com/influxdb/v1.7/query_language/) (which is very similar to the SQL query language) and simply selects all the pressure and temperature readings from the bmp280_sensor measurement.  Notice the temperature value is divided by 1000 so that the queried results are converted to degrees Celsius instead of using their native milli-degrees value.

Click the chart icon (Visualization) on the left of the query and Grafana will let you change how the query results are displayed in the panel.  Click the Graph title next to Visualization at the top and you'll see an array of different panel visualizations displayed.  Choose the Table visualization for a simple table view:
![](images/balena_grafana_visualization.png?raw=true)

There are many more options to explore to configure and tweak how panels display information.  For now we'll save this simple table view by clicking the save icon at the very top of the page.  Give the dashboard a descriptive name and save it:
![](images/balena_grafana_save.png?raw=true)

You should see the new table panel in the dashboard!
![](images/balena_grafana_dashboard.png?raw=true)

You can add more panels to display information in other ways, like graphs and gauges.  Click the Add Panel button that's highlighted at the top of the screen and try adding a new panel to display a guage with the latest temperature reading:
![](images/balena_grafana_query_gauge.png?raw=true)
![](images/balena_grafana_gauge.png?raw=true)
![](images/balena_grafana_gauge_general.png?raw=true)

Now your dashboard has a slick gauge that shows the latest temperature reading!
![](images/balena_grafana_gauge_dashboard.png?raw=true)

Be sure to save the change to the dashboard so it's not lost!

This is just scratching the surface of what's possible with Grafana and InfluxDB.  Check out the [Grafana documentation](http://docs.grafana.org/guides/getting_started/) for many more details on different panel types, dashboards, etc.  The [InfluxDB query language documentation](https://docs.influxdata.com/influxdb/v1.7/query_language/) is handy to skim for an overview of how to query data.

Let's go back to the application code and examine the containers inside it in a little more detail so we can understand how everything works.

## docker-compose.yml

If you examine the docker-compose.yml in the application code folder you'll see how it defines multiple services that make up this project:
````
version: '2'

services:

  influxdb:
    build: influxdb
    restart: on-failure
    volumes:
      - 'influxdb-data:/var/lib/influxdb'

  grafana:
    build: grafana
    depends_on:
      - influxdb
    ports:
      - '80:3000'
    restart: on-failure
    volumes:
      - 'grafana-data:/var/lib/grafana'

  dtoverlay-enviro-phat:
    build: dtoverlay
    command: apply_overlays enviro-phat
    privileged: true
    restart: no

  bmp280-sensor:
    build: telegraf
    depends_on:
      - influxdb
      - dtoverlay-enviro-phat
    environment:
      - 'TELEGRAF_EXEC_COMMAND=/collect/bmp280.sh'
    restart: on-failure

  ads1015-sensor:
    build: telegraf
    depends_on:
      - influxdb
      - dtoverlay-enviro-phat
    environment:
      - 'TELEGRAF_EXEC_COMMAND=/collect/ads1015.sh'
    restart: on-failure

volumes:
  influxdb-data:
  grafana-data:
````

This file follows the [Docker compose format](https://docs.docker.com/compose/compose-file/compose-file-v2/) and is used to define a [multi-container application with Balena](https://www.balena.io/docs/learn/develop/multicontainer/).  Let's go through each service in more detail to understand how they all work together.

## influxdb Service

This service defines the InfluxDB database that will store sensor measurements.  You can see how the service builds a Dockerfile defined in the influxdb subfolder.  Looking at the contents of the Dockerfile you can see this is a very simple service:
````
FROM arm32v7/influxdb

# Add custom config.
COPY influxdb.conf /etc/influxdb/influxdb.conf
````

The InfluxDB Dockerfile simply uses the [official InfluxDB ARM container on Dockerhub](https://hub.docker.com/r/arm32v7/influxdb/) and copies in a custom configuration file to adjust InfluxDB's behavior.  In this project the InfluxDB configuration is unchanged from the defaults, but if necessary you can change any of the values in the influxdb.conf file and tweak the behavior of the database.

You might be curious why the Dockerfile uses an ARM build of the InfluxDB container.  This is to ensure that the builders run by Balena pick up the right format container for the devices in the application.  InfluxDB publishes containers for all major architectures including ARM and x86 machines.  Docker support for multiple architectures has been evolving and currently the best practice is to explicitly reference a necessary architecture, like arm32v7 for Raspberry Pi 3 devices.

Note that the INFLUXDB_DB, INFLUXDB_USER, etc. environment variables that you set in the application are actually used internally by this container to configure and provision databases in InfluxDB.  You can learn more about these environment variables from the [InfluxDB container Dockerhub homepage](https://hub.docker.com/r/arm32v7/influxdb/).

Also notice the influxdb service defines a named volume to persist data.  This volume will ensure that measurements stored in InfluxDB are not lost when the container shuts down and restarts.

## grafana Service

The grafana service defines the Grafana dashboard that visualizes data.  You can examine the Dockerfile in the grafana subfolder to see how this container is built.  Notice that this Dockerfile is slightly different and more complex than the InfluxDB container.  There are a few reasons why this container is more complex than others:
*   Grafana only distributes ARM binaries and not ARM containers like InfluxDB.  To work around this the Dockerfile uses an ARM Debian base image from [Balena's library of base images](https://www.balena.io/docs/reference/base-images/base-images/) and runs the necessary commands to download and install an ARM build of Grafana.
*   The container includes a provisioning folder inside which automatically configures Grafana to have a datasource connected to the InfluxDB service.  This uses a special [Grafana datasource provisioning hook](http://docs.grafana.org/administration/provisioning/#datasources) to ensure Grafana is configured out of the box with the datasource.
*   To work around a limitation that Grafana's provisioning configurations can't read environment variables the container sets up a run.sh script to inject these environment values in the provisioning config before Grafana runs.  If you examine the run.sh script you can see it uses an `envsubst` command to replace environment variable names with their values in the provisoning configuration.  This is necessary to make sure Grafana configures the InfluxDB datasource with the right database name, username, and password.

Notice the service definition of the grafana service specifies a dependency on the influxdb service.  This dependency ensures the grafana service won't be started until the influxdb service has started.

In addition you can see the grafana service configures a port mapping from port 3000 inside the container to be visible as port 80 on the device.  This mapping moves it to port 80 for convenience, and the ability to enable a public URL for the device in Balena cloud (allowing you to view the dashboard from anywhere!).  Simply turn on the **Public URL** setting in the device page of the application dashboard and you can access a URL that tunnels through to your device's Grafana dashboard.

## dtoverlay-enviro-phat Service

This service uses the dtoverlay Dockerfile from the [first part of this series](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/index.md) to build and apply a device tree overlay that enables the BMP280 and ADS1015 sensors on the Enviro-pHAT.

## bmp280-sensor and ads1015-sensor Services

These services use Telegraf to collect data from the Enviro-pHAT sensors and store measurements in InfluxDB.  Both services are built from the telegraf subfolder's Dockerfile, but notice how each slightly differs in the environment configuration.  The **TELEGRAF_EXEC_COMMAND** environment variable is specified with a unique script per service that collects the appropriate sensor readings.

You can find the collection scripts in the collect subdirectory of the telegraf service.  For example the bmp280.sh script contains:
````
#!/bin/bash
# IIO-based BMP280 pressure/temperature sensor collection script.
set -eu

# Configuration:
IIO_DEVICE=/sys/bus/iio/devices/iio:device0     # IIO device path
MEASUREMENT=bmp280_sensor                       # Measurement name to store
                                                # in InfluxDB database.

cd $IIO_DEVICE
echo $MEASUREMENT pressure=$(cat in_pressure_input),temperature=$(cat in_temp_input)
````

This is a simple shell script that changes to the IIO device subdirectory and reads the pressure and temperature from the sensor, just like you saw in the [first part of this series](https://github.com/tdicola/balena_logging_sensors_pt_1/blob/master/index.md).  Telegraf works by running this script and reading lines of output from it to parse out measurements.  The echo line at the bottom of the script is what prints measurements, and it does so using a special [InfluxDB line format](https://docs.influxdata.com/influxdb/v1.7/write_protocols/line_protocol_tutorial/).

Notice how the line format is simply the measurement name (bmp280_sensor, what you saw when querying data in Grafana), a space, and then a comma separated list of &lt;measurement&gt;=&lt;value&gt; pairs (where values are read directly from the IIO nodes like in_pressure_input).

This telegraf container is built to be easily extended and used with any other sensors.  Simply create new shell scripts in the collect folder and put in whatever code you need to measure your sensor.  You could even call a program you write in Python, Node.js, etc. to grab measurements with other tools and libraries!  You only have to ensure the script or program prints lines in the InfluxDB line format.

One other thing to note with the telegraf container is that it has a configuration file called telegraf.conf.  This file allows you to adjust the behavior of Telegraf, like how often it reads sensor data (by default every 10 seconds).

That's all there is to the services that make up a TIG stack for collecting and visualizaing Enviro-pHAT sensor data!

# Summary

In this project you saw the second part of a three part series on datalogging sensors with Balena's platform.  You learned how to create an application in Balena Cloud and deploy a multi-container collection of services.  These services use the TIG stack with Telegraf, InfluxDB, and Grafana to collect, store, and visualize data.  The next and final project in this series will explore how to run multiple devices with different sensors logging to a single TIG stack.
