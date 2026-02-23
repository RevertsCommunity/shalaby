#!/bin/bash

set -e

###################################################
# Variable definitions
###################################################

# Prevent interactive prompts during install
DEBIAN_FRONTEND=noninteractive

APT_DEPENDENCIES=(
  wget              # cook
  make              # cook
  inkscape          # cook
  ffmpeg            # cook
  flac              # cook
  fdkaac            # cook
  vorbis-tools      # cook
  opus-tools        # cook
  zip               # cook
  unzip             # cook
  lsb-release       # redis
  curl              # redis
  gpg               # redis
  postgresql        # web
  dbus-x11          # install
  sed               # install
  coreutils         # install
  build-essential   # install
  python-setuptools # install
)

# Get the directory of the script being executed
craig_dir=$(dirname "$(realpath "$0")")

# Marker to skip install and config steps if they have already completed
INSTALL_MARKER="$craig_dir/.installed"
FORCE_INSTALL=0

#Get the init system
init_system=$(ps --no-headers -o comm 1)

###################################################
# Function definitions
###################################################

usage() {
  cat <<EOS
Install Craig for local development
Usage: install.sh [options]

options:
    -h, --help       Display this message.
    -f, --force-install
                     Force application rebuild.

Ensure that all required environment variables are passed to the container
prior to running this script (e.g., DISCORD_BOT_TOKEN, NODE_VERSION, DATABASE_NAME).

Various steps are required to run local instances of Craig.
The steps are summarized below:

  1) Install apt and react packages
  2) Start Redis
  3) Start PostgreSQL
  4) Configure react and yarn
  5) Build audio processing utilities
  6) Start application

If all steps are successfully ran, you can monitor the application using the 'pm2' utility:

  pm2 monit

EOS
  exit "${1:-0}"
}

warning() {
    echo "[Craig][Warning]: $1"
}

error() {
    echo "[Craig][Error]: $1" >&2
}

info() {
    echo "[Craig][Info]: $1"
}

install_apt_packages() {
  info "Updating and upgrading apt packages..."
  sudo apt-get update
  sudo apt-get -y upgrade

  info "Installing apt dependencies..."
  sudo apt-get -y install "${APT_DEPENDENCIES[@]}"

  curl -fsSL https://packages.redis.io/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
  sudo apt-get update || true
  sudo apt-get -y install redis
}

install_node() {
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  
  source ~/.nvm/nvm.sh || true

  nvm install $NODE_VERSION
  nvm use $NODE_VERSION

  npm install -g yarn
  npm install -g pm2
}

start_redis() {
  local start_time_s
  local current_time_s

  source ~/.nvm/nvm.sh || true
  nvm use $NODE_VERSION

  info "Starting Redis server..."

  if ! redis-cli ping | grep -q "PONG"
  then
    if [[ $init_system == "systemd" ]]
    then
      sudo systemctl enable --now redis-server 
    else
      redis-server --daemonize yes 
    fi
    start_time_s=$(date +%s)

    while ! redis-cli ping | grep -q "PONG"
    do
      current_time_s=$(date +%s)
      sleep 1 

      if [[ $current_time_s-$start_time_s -ge $REDIS_START_TIMEOUT_S ]]
      then
        error "Redis server is not running or not accepting connections"
        exit 1
      fi
    done 
  fi
}

start_postgresql() {
  local start_time_s
  local current_time_s

  info "Starting PostgreSQL server..."

  if ! pg_isready
  then
    if [[ $init_system ==  "systemd" ]]
    then
      sudo systemctl enable --now postgresql
    else
      sudo /etc/init.d/postgresql start 
    fi

    start_time_s=$(date +%s)

    while ! pg_isready
    do
      current_time_s=$(date +%s)
      sleep 1 

      if [[ $current_time_s-$start_time_s -ge $POSTGRESQL_START_TIMEOUT_S ]]
      then
        error "PostgreSQL server is not running or not accepting connections"
        exit 1
      fi
    done 
  fi

  if sudo -u postgres -i psql -lqt | cut -d \| -f 1 | grep -qw "$DATABASE_NAME"
  then
    info "PostgreSQL database '$DATABASE_NAME' already exists."
  else
    sudo -u postgres -i createdb $DATABASE_NAME
  fi 

  if ! sudo -u postgres -i psql -t -c '\du' | cut -d \| -f 1 | grep -qw "$POSTGRESQL_USER"
  then
    sudo -u postgres -i psql -c "CREATE USER $POSTGRESQL_USER WITH PASSWORD '$POSTGRESQL_PASSWORD';"
  else
    info "PostgreSQL user '$POSTGRESQL_USER' already exists."
  fi

  sudo -u postgres -i psql -c "GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO $POSTGRESQL_USER;"
  sudo -u postgres -i psql -c "GRANT ALL ON SCHEMA public TO $POSTGRESQL_USER;"
  sudo -u postgres -i psql -c "GRANT USAGE ON SCHEMA public TO $POSTGRESQL_USER;"
  sudo -u postgres -i psql -c "ALTER DATABASE $DATABASE_NAME OWNER TO $POSTGRESQL_USER;"
  
  sudo -u postgres -i psql -c "\l" 
}

config_react(){
  info "Configuring react..."

  cp "$craig_dir/apps/bot/config/_default.js" "$craig_dir/apps/bot/config/default.js" 
  cp "$craig_dir/apps/tasks/config/_default.js" "$craig_dir/apps/tasks/config/default.js" 

  # Extract protocol and domain from API_HOMEPAGE
  DOWNLOAD_PROTOCOL=$(echo "$API_HOMEPAGE" | awk -F '://' '{print $1}')
  DOWNLOAD_DOMAIN=$(echo "$API_HOMEPAGE" | awk -F '://' '{print $2}')

  # Perform in-place replacement in the config file using injected env vars
  sed -z -E -i'' "s/(dexare:.*token:\s*)('')(.*applicationID:\s*)('')(.*downloadProtocol:\s*)('https')(.*downloadDomain:\s*)('localhost:5029')/\
  \1'${DISCORD_BOT_TOKEN}'\3'${DISCORD_APP_ID}'\5'${DOWNLOAD_PROTOCOL}'\7'${DOWNLOAD_DOMAIN//\//\\/}'/" \
  "$craig_dir/apps/bot/config/default.js"

  sed -z -E -i "s/(tasks:.*ignore:\s*)(\[\s*\])/\
  \1[\"refreshPatrons\"]/"\
  "$craig_dir/apps/tasks/config/default.js"
}

config_yarn(){
  info "Configuring yarn..."

  yarn install
  yarn prisma:generate
  yarn prisma:deploy
  yarn run build
  yarn run sync
}

start_app(){
  source ~/.nvm/nvm.sh || true
  nvm use $NODE_VERSION

  info "Starting Craig..."

  cd "$craig_dir/apps/bot" && pm2 start "ecosystem.config.js"
  cd "$craig_dir/apps/dashboard" && pm2 start "ecosystem.config.js"
  cd "$craig_dir/apps/download" && pm2 start "ecosystem.config.js"
  cd "$craig_dir/apps/tasks" && pm2 start "ecosystem.config.js"

  pm2 save

  cd "$craig_dir"
}

config_cook(){
  info "Building cook..."
  mkdir -p "$craig_dir/rec"
  "$craig_dir/scripts/buildCook.sh"
  "$craig_dir/scripts/downloadCookBuilds.sh"
}

###################################################
# Main script commands
###################################################

{ 
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      -h | --help)
        usage ;;
      -f|--force-install)
        FORCE_INSTALL=1
        shift ;;
      *)
        warning "Unrecognized option: '$1'"
        usage 1
        ;;
    esac
  done

  if [[ "$FORCE_INSTALL" == "1" ]]; then
    rm -f "$INSTALL_MARKER"
  fi

  if [ "$(whoami)" == "root" ]; then
    apt-get install -y sudo
  fi

  info "This script requires sudo privileges to run"

  if ! sudo -v; then
    error "Sudo password entry was cancelled or incorrect."
    exit 1 
  fi

  OS="$(uname)"
  if [[ "${OS}" != "Linux" ]]
  then
    error "Craig is only supported on Linux."
    exit 1
  fi

  info "Now installing Craig..."
  info "Start time: $(date +%H:%M:%S)"

  if [[ ! -f "$INSTALL_MARKER" ]]; then
    install_apt_packages
    install_node
  else
    info "Skipping install: already completed"
  fi

  if [[ $container != "docker" ]]
  then
    start_redis
    start_postgresql
  fi

  if [[ ! -f "$INSTALL_MARKER" ]]; then
    config_react
    config_yarn
    config_cook
    touch "$INSTALL_MARKER"
  else
    info "Skipping config: already completed"
  fi

  start_app

  info "Craig installation finished..."
  info "End time: $(date +%H:%M:%S)"
  info "Log output: $craig_dir/install.log"

} 2>&1 | tee "$craig_dir/install.log"
