FROM ghcr.io/shardeum/server:latest

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

# Set the app home directory
ENV APP_HOME=/home/node/app

RUN apt-get update && apt-get install -y sudo logrotate

# Modify sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up node user
RUN usermod -aG sudo node

# Create app directory
RUN mkdir -p $APP_HOME && chown node:node $APP_HOME

# Switch to node user
USER node

WORKDIR $APP_HOME

# Copy package files with correct ownership and install dependencies
COPY --chown=node:node package*.json ./
RUN npm ci

# Copy the rest of the files with correct ownership
COPY --chown=node:node . .

# Create symlink
RUN ln -s /usr/src/app $APP_HOME/validator

# Start entrypoint script
CMD ["./entrypoint.sh"]