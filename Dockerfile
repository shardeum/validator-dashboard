FROM registry.gitlab.com/shardeum/shardeum-server:1.0.0.0

# Create node user
RUN usermod -aG sudo node && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share && \
    chown -R node /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share
USER node

# Copy cli src files as regular user
WORKDIR /home/node/app/operator
COPY --chown=node:node . .

# Start entrypoint script as regular user
CMD ["./entrypoint.sh"]
