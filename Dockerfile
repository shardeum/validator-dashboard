###################################################################################
# Set the branch to build from the command line with --build-arg, for example:
# $ docker build --build-arg VALIDATOR_BRANCH=itn-1.15.2 .
###################################################################################
ARG VALIDATOR_BRANCH="dev"
ARG CLI_BRANCH="dev"
ARG GUI_BRANCH="dev"

## This should not be changed often or easily without thourough testing
ARG NODE_VERSION=18.19.1

###################################################################################
### Build the Shardeum Validator image from https://github.com/shardeum/shardeum
###################################################################################
FROM node:${NODE_VERSION} AS validator
ARG VALIDATOR_BRANCH

# Install Rust build chain for modules
RUN apt-get update && apt-get install -y \
    build-essential \
    curl
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
RUN . $HOME/.cargo/env
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup install 1.74.1 && rustup default 1.74.1


WORKDIR /usr/src/app
#ENV NODE_ENV=production
ENV VALIDATOR_BRANCH=${VALIDATOR_BRANCH}
RUN git clone https://github.com/shardeum/shardeum.git . && \
    git switch ${VALIDATOR_BRANCH} && \
    npm install && \
    npm run compile


###################################################################################
### Build the CLI image from https://github.com/shardeum/validator-cli
###################################################################################
FROM node:${NODE_VERSION} AS cli
ARG CLI_BRANCH

RUN mkdir -p /home/node/app/cli && chown -R node:node /home/node/app && chmod 2775 -R /home/node/app
#RUN npm install typescript -g
USER node
WORKDIR /home/node/app
#ENV NODE_ENV=production
ENV CLI_BRANCH=${CLI_BRANCH}
RUN git clone https://github.com/shardeum/validator-cli.git cli && cd cli && \
    git switch ${CLI_BRANCH} && \
    npm install && \
    npm run compile


###################################################################################
### Build the GUI image from https://github.com/shardeum/validator-gui
###################################################################################
FROM node:${NODE_VERSION} AS gui
ARG GUI_BRANCH

RUN mkdir -p /home/node/app/gui && chown -R node:node /home/node/app/gui && chmod 2775 -R /home/node/app/gui

USER node
WORKDIR /home/node/app
#ENV NODE_ENV=production
ENV GUI_BRANCH=${GUI_BRANCH}
RUN git clone https://github.com/shardeum/validator-gui.git gui && cd gui && \
    git switch ${GUI_BRANCH} && \
    npm install && \
    npm run build


###################################################################################
### Build the final image
###################################################################################
FROM node:${NODE_VERSION} AS final

# Link this Dockerfile to the image in the GHCR
LABEL "org.opencontainers.image.source"="https://github.com/shardeum/validator-dashboard"

RUN mkdir -p /home/node/app /usr/src/app && chown -R node:node /home/node/app /usr/src/app && chmod 2775 -R /home/node/app /usr/src/app
COPY --from=validator --chown=node:node /usr/src/app /usr/src/app
COPY --from=cli --chown=node:node /home/node/app/cli /home/node/app/cli
COPY --from=gui --chown=node:node /home/node/app/gui /home/node/app/gui

RUN cd /home/node/app/cli && npm link
RUN ln -s /usr/src/app /home/node/app/validator
RUN npm install -g pm2
RUN echo '/home/node/.pm2/logs/*.log /home/node/app/cli/build/logs/*.log {\n\
    daily\n\
    rotate 7\n\
    compress\n\
    delaycompress\n\
    missingok\n\
    notifempty\n\
    create 0640 user group\n\
    sharedscripts\n\
    postrotate\n\
    pm2 reloadLogs\n\
    endscript\n\
}"' > /etc/logrotate.d/pm2


## The GUI s optional, and the validator might restart due to network events, so neither make good candidates for ENTRYPOINT
## pm2 logs is a good default to keep the instance running & have useful output.
USER node
WORKDIR /home/node/app/gui
CMD [ "pm2-runtime", "logs" ]
