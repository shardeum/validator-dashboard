# NOTE: This Dockerfile compiles an image that uses Debian Stretch as its OS
#
# Build time is fast because the native modules used by our app
# (sodium-native, sqlite3) have precomiled binaries for Debian.
#
# However, the resulting image size is very large (~1.25GB).
#
# Useful for development

# Debian Stable from Docker Hub
FROM debian:stable

# Install needed packages
RUN apt-get update
RUN apt-get install -y \
    git \
    python3 \
    build-essential \
    curl \
    sudo \
    software-properties-common
RUN apt-get update

# Create node user
RUN useradd -ms /bin/bash node && \
  usermod -aG sudo node && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER node

# Copy src files as regular user
WORKDIR /home/node/app
COPY --chown=node:node . .

# Install Rust and Node 16 LTS as regular user
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y && \
  echo 'source $HOME/.cargo/env' >> $HOME/.bashrc && \
  sudo mkdir -p /usr/local/n && \
  sudo chown -R node /usr/local/n && \
  sudo mkdir -p /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share && \
  sudo chown -R node /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share && \
  curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n && \
  bash n 16.11.1 && \
  npm config set python python3
ENV PATH /home/node/.cargo/bin:$PATH

# Start entrypoint script as regular user
CMD ["./entrypoint.sh"]
