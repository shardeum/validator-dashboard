FROM ghcr.io/shardeum/server:latest

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

# Set the app home directory
ENV APP_HOME=/home/node/app

RUN apt-get update

RUN apt-get install -y sudo
RUN apt-get install -y logrotate

# Create node user
RUN usermod -aG sudo node && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p $APP_HOME /usr/src/app
USER node

# Copy cli src files as regular user
WORKDIR $APP_HOME
COPY --chown=node:node . $APP_HOME

RUN ln -s /usr/src/app $APP_HOME/validator

# Start entrypoint script as regular user
CMD ["./entrypoint.sh"]
