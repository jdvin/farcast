#!/bin/bash

# Default values:
LOCAL_PATH=./

if [[ "$#" -eq 0 ]]; then
  echo "Usage: farcast.sh [options]"
  echo "  -h, --remote-host      The host name in ~/.ssh/config."
  echo "  -r, --remote-path      Path from the home directory on the remote host."
  echo "  -l, --local-path       The destination path from the execution directory locally."
  echo "  -t, --target-dir       The directory to sync."
  echo "  -p, --pull-first       Pull files from remote host before watching for changes."
  echo "  -e, --exclude-dirs     Comma-separated list of directories to exclude."
  exit 1
fi

# Read arguments.
while [[ "$#" -gt 0 ]]
do
  case $1 in
    -h|--remote-host) REMOTE_HOST="$2"; shift;;
    -r|--remote-path) REMOTE_PATH="$2"; shift;;
    -l|--local-path) LOCAL_PATH="$2"; shift;;
    -t|--target-dir) TARGET_DIR="$2"; shift;;
    -p|--pull-first) PULL_FIRST=1; shift;;
    -e|--exclude-dirs) EXCLUDE_DIRS="$2"; shift;;
  esac
  shift
done

if [ -z "$REMOTE_HOST" ]; then
  echo "Remote host is not set"
  exit 1
fi

if [ -z "$TARGET_DIR" ]; then
  echo "Target directory is not set"
  exit 1
fi

# Parse and format the exclude directories:
EXCLUDE_STRING=""
if [ ! -z "$EXCLUDE_DIRS" ]; then
  IFS=',' read -ra ADDR <<< "$EXCLUDE_DIRS"
  for dir in "${ADDR[@]}"; do
    EXCLUDE_STRING+="--exclude=${dir} "
  done
fi

if [ "$PULL_FIRST" == 1 ]; then
  # Pull files from remote to local.
  echo "Pulling files from remote host $REMOTE_HOST:$REMOTE_PATH$TARGET_DIR to local directory $LOCAL_PATH$TARGET_DIR."
  rsync -Pazvh --delete -e ssh $EXCLUDE_STRING $REMOTE_HOST:$REMOTE_PATH$TARGET_DIR/ $LOCAL_PATH$TARGET_DIR
fi

function run_rsync () { 
  while read f; do 
    # Push files from local to remote.
    rsync -Pazvh -e ssh $EXCLUDE_STRING $LOCAL_PATH$TARGET_DIR/ $REMOTE_HOST:$REMOTE_PATH$TARGET_DIR
  done
}

rsync -Pazvh -e ssh $EXCLUDE_STRING $LOCAL_PATH$TARGET_DIR/ $REMOTE_HOST:$REMOTE_PATH$TARGET_DIR
echo "Watching for changes in $LOCAL_PATH$TARGET_DIR"

# Watch for changes and run rsync when changes are detected.
fswatch -o $LOCAL_PATH$TARGET_DIR | run_rsync
