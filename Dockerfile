FROM ghcr.io/shardeum/server:latest

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

RUN apt-get update && apt-get install -y sudo logrotate

# Modify sudoers and set up node user
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    usermod -aG sudo node && \
    mkdir -p /home/node/app /usr/src/app && \
    chown -R node:node /home/node /usr/src/app /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share

# Switch to node user
USER node

# Set up symbolic link
RUN ln -s /usr/src/app /home/node/app/validator

# Set working directory
WORKDIR /home/node/app

# Copy files with correct ownership
COPY --chown=node:node . .

# Install PM2 globally
RUN npm install -g pm2

# Set up logrotate configuration
RUN echo "/home/node/.pm2/logs/*.log /home/node/app/cli/build/logs/*.log {\n\
    daily\n\
    rotate 7\n\
    compress\n\
    delaycompress\n\
    missingok\n\
    notifempty\n\
    create 0640 node node\n\
    sharedscripts\n\
    postrotate\n\
        pm2 reloadLogs\n\
    endscript\n\
}" | sudo tee /etc/logrotate.d/pm2

# Start entrypoint script
CMD ["./entrypoint.sh"]