FROM vaultwarden/server:latest

# ONCE expects persistent data at /storage and HTTP on port 80.
# Vaultwarden stores data in /data by default, so we symlink.
# Vaultwarden's Rocket server already listens on port 80.

# Install sqlite3 for safe backup snapshots
RUN apt-get update && \
    apt-get install -y --no-install-recommends sqlite3 && \
    rm -rf /var/lib/apt/lists/*

# Hook scripts for ONCE backup/restore integration
COPY hooks/ /hooks/
RUN chmod +x /hooks/*

# Entrypoint that maps ONCE env vars and starts vaultwarden
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
