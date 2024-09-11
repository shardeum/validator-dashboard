FROM ghcr.io/shardeum/server:latest

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

# Set the app home directory
ENV APP_HOME=/home/node/app

RUN apt-get update && apt-get install -y sudo logrotate

# Modify sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up node user
RUN usermod -aG sudo node && \
    chown -R node:node /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share

# Switch to node user
USER node

# Create app directory and set ownership
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

# Copy files with correct ownership
COPY --chown=node:node . $APP_HOME

# Create symlink
RUN ln -s /usr/src/app $APP_HOME/validator

# Start entrypoint script
CMD ["./entrypoint.sh"]