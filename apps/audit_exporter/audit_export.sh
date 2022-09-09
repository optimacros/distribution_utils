#!/bin/bash

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      echo "Export audit script"
      echo " "
      echo "Audit [options] application [arguments]"
      echo " "
      echo "options:"
      echo "-h, --help        show help"
      echo "-e, --env         path to .env file with a config data"
      exit 0
      ;;
    -e|--env)
      envPath="$2"
      shift
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

export $(grep -v '^#' "$envPath" | xargs)

if [ -z "$START_DATE" ]
then
    START_DATE=$(date +'%F')
fi

if [ -z "$END_DATE" ]
then
    END_DATE=$(date -I -d "$START_DATE + 1 day")
fi

./base.sh -t "$APPLICATION_TYPE" -c "$CONFIG_PATH" -p "$PROJECT_PATH" -s "$START_DATE" -e "$END_DATE" -o "$TARGET_DIR"