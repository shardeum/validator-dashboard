FROM ghcr.io/shardeum/server:devnets

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

RUN apt-get update

RUN apt-get install -y sudo
RUN apt-get install -y logrotate

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
