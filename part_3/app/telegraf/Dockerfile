FROM arm32v7/telegraf

# Add custom config and collection scripts.
COPY telegraf.conf /etc/telegraf/telegraf.conf
COPY collect /collect

# Add custom entrypoint script to allow running on specific devices, materialize
# config into files, etc.
COPY balena_entrypoint.sh /balena_entrypoint.sh

# Override the entrypoint to use our custom one and further call into the base
# image's entrypoint.
ENTRYPOINT [ "/balena_entrypoint.sh", "/entrypoint.sh" ]
CMD [ "telegraf" ]
