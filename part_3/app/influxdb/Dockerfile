FROM arm32v7/influxdb

# Add custom config.
COPY influxdb.conf /etc/influxdb/influxdb.conf

# Add custom entrypoint script to allow running on specific devices, materialize
# config into files, etc.
COPY balena_entrypoint.sh /balena_entrypoint.sh

# Generate a self-signed SSL certificate to encrypt traffic to InfluxDB.
# For a hardened production environment you should get proper certificates
# from a real certificate authority and replace this self-signed logic
# (realize you might need to update the influxdb.conf too, and you must think
# carefully about the risks of copying the certs into the container image here).
RUN openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
    -subj "/CN=influxdb" \
    -keyout /etc/ssl/influxdb-selfsigned.key \
    -out /etc/ssl/influxdb-selfsigned.crt

# Override the entrypoint to use our custom one and further call into the base
# image's entrypoint.
ENTRYPOINT [ "/balena_entrypoint.sh", "/entrypoint.sh" ]
CMD [ "influxd" ]
