FROM ghcr.io/shardeum/server:1.12.1rc3

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

RUN apt-get update && \
    apt-get install -y sudo logrotate && \
    rm -rf /var/lib/apt/lists/*

# Create node user
RUN usermod -aG sudo node && \
 echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
 chown -R node /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share
USER node

# Copy cli src files as regular user
WORKDIR /home/node/app
COPY --chown=node:node . .

# RUN ln -s /usr/src/app /home/node/app/validator

# Start entrypoint script as regular user
CMD ["./entrypoint.sh"]
