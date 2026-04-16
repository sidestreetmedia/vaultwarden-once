FROM vaultwarden/server:latest

# ONCE expects HTTP on port 80 and persistent data at /storage.
# ONCE's kamal-proxy health-checks GET /up expecting a 200.
# Vaultwarden doesn't serve /up, so we put nginx in front to handle it.

# Install nginx and sqlite3
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx sqlite3 && \
    rm -rf /var/lib/apt/lists/*

# Nginx config: /up returns 200, everything else proxies to vaultwarden
COPY nginx.conf /etc/nginx/nginx.conf

# Hook scripts for ONCE backup/restore integration
COPY hooks/ /hooks/
RUN chmod +x /hooks/*

# Entrypoint that maps ONCE env vars and starts vaultwarden + nginx
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
