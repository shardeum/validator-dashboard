ARG SERVER_VERSION=latest
FROM registry.gitlab.com/shardeum/server:${SERVER_VERSION}

ARG RUNDASHBOARD=y
ENV RUNDASHBOARD=${RUNDASHBOARD}

RUN apt-get update \
  && apt-get install -y sudo logrotate \
  && usermod -aG sudo node \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers \
  && chown -R node /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER node

# Copy cli src files as regular user
WORKDIR /home/node/app
COPY --chown=node:node . .

# RUN ln -s /usr/src/app /home/node/app/validator

# Start entrypoint script as regular user
CMD ["./entrypoint.sh"]
