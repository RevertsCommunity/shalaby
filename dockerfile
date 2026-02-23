# Use an official Ubuntu base image
FROM ubuntu:22.04

# Install all required dependencies in advance, for performance
RUN apt-get update && \
    apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    # cook
    make inkscape ffmpeg flac fdkaac vorbis-tools opus-tools zip unzip \
    wget \
    # redis
    lsb-release curl gpg \
    ca-certificates redis redis-server redis-tools \
    # web
    postgresql \
    # install
    dbus-x11 sed coreutils build-essential python-setuptools \
    # Other dependencies
    sudo git locales && \
    # Cleanup
    apt-get -y autoremove

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Used for Docker-specific build logic in install.sh
ENV container=docker

WORKDIR /app

# Copy the repo, particularly environment variables with discord API keys
COPY . .

# Catch the build arguments passed from docker-compose
ARG NODE_VERSION
ARG DISCORD_BOT_TOKEN
ARG DISCORD_APP_ID
ARG API_HOMEPAGE
ARG DATABASE_NAME
ARG POSTGRESQL_USER
ARG POSTGRESQL_PASSWORD
ARG REDIS_START_TIMEOUT_S
ARG POSTGRESQL_START_TIMEOUT_S

# Convert them into environment variables so the install script can see them
ENV NODE_VERSION=$NODE_VERSION
ENV DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN
ENV DISCORD_APP_ID=$DISCORD_APP_ID
ENV API_HOMEPAGE=$API_HOMEPAGE
ENV DATABASE_NAME=$DATABASE_NAME
ENV POSTGRESQL_USER=$POSTGRESQL_USER
ENV POSTGRESQL_PASSWORD=$POSTGRESQL_PASSWORD
ENV REDIS_START_TIMEOUT_S=$REDIS_START_TIMEOUT_S
ENV POSTGRESQL_START_TIMEOUT_S=$POSTGRESQL_START_TIMEOUT_S

# Run first-time setup for faster restarts
RUN ./install.sh

# Expose app port
EXPOSE 7777
# Expose API port
EXPOSE 5029
# Start Craig
CMD ["sh", "-c", "/app/install.sh && sleep infinity"]

