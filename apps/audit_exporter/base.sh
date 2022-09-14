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
      echo "-h, --help         show help"
      echo "-t, --type         application type. Possible values: mw - middlework application; lc - login center"
      echo "-p, --pathConfig   config path. Path to manifest in case of MW or to .env file in case of LC contained password"
      echo "-v, --vagrant      path to vagrant container file exported from"
      echo "-s, --startDate    export starting from UTC date(Y-m-d format)"
      echo "-e, --endDate      export up to from UTC date(Y-m-d format). End date must be greater than start date"
      echo "-o, --output       output directory"
      echo "-u, --user         mongo user"
      echo "-d, --db           mongo database"
      echo "-c, --collection   mongo collection"
      exit 0
      ;;
    -t|--type)
      appType="$2"
      shift
      shift
      ;;
    -p|--pathConfig)
      configPath="$2"
      shift
      shift
      ;;
    -v|--vagrantPath)
      vagrantPath="$2"
      shift
      shift
      ;;
    -o|--output)
      outputDir="$2"
      shift
      shift
      ;;
    -s|--startDate)
      startDate="$2"
      shift
      shift
      ;;
    -e|--endDate)
      endDate="$2"
      shift
      shift
      ;;
    -u|--user)
      mUser="$2"
      shift
      shift
      ;;
    -d|--db)
      mDB="$2"
      shift
      shift
      ;;
    -c|--collection)
      mCollection="$2"
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

tmp="/tmp/temp_audit_file"
d="$startDate"

if [ -z "$startDate" ]
then
  echo "start date flag is empty, terminated"
  exit 1
fi

if [ -z "$endDate" ]
then
  echo "end date flag is empty, terminated"
  exit 1
fi

if [ -z "$configPath" ]
then
  echo "end date flag is empty, terminated"
  exit 1
fi

if [ -z "$outputDir" ]
then
  echo "target dir flag is empty, terminated"
  exit 1
fi

if [[ "$appType" == "mw" ]]; then
    if [ -z "$vagrantPath" ]
    then
      echo "path to directory with vagrant container is empty, terminated"
      exit 1
    fi

    if [ -z "$mUser" ]
    then
      mUser='admin'
    fi

    mPassword=$(cat "$configPath" | grep "mongodb" -C3 | grep "$mUser" | awk -v RS='\r\n' "/$mUser/ { gsub(/[\",]/,\"\",\$2); print \$2}")

    if [ -z "$vagrantPath" ]
    then
      echo "Can not parse password for user: $mUser"
      exit 1
    fi

    if [ -z "$mDB" ]
    then
      mDB='optimacros_audit'
    fi

    if [ -z "$mCollection" ]
    then
      mCollection='events'
    fi

    version=$(cd "$vagrantPath" && vagrant ssh -- -t -q cat /home/vagrant/optimacros_middlework/app/config/version.php | grep return | cut -d"'" -f 2)

  elif [[ "$appType" == "lc" ]]; then
    if [ -z "$mUser" ]
    then
      mUser=$(cat "$configPath" | grep 'DB_USERNAME' | awk -v RS='\r\n' -F'=' '{print $2}')
    fi

    mPassword=$(cat "$configPath" | grep 'DB_PASSWORD' | awk -v RS='\r\n' -F'=' '{print $2}')

    if [ -z "$mPassword" ]
    then
      echo "Can not parse password for user: $mUser"
      exit 1
    fi

    if [ -z "$mDB" ]
    then
      mDB='logincenter'
    fi

    if [ -z "$mCollection" ]
    then
      mCollection='audit'
    fi

    version=$(cat "$configPath" | grep 'VERSION' | awk -v RS='\r\n' -F'=' '{print $2}')
  else
    echo "wrong application type provided"
    exit 1
  fi


endDate=$(date -I -d "$endDate + 1 day")

while [ "$d" != "$endDate" ]; do
  echo "Start export for date: $d"

  dateF=$(date -d "$d" +'%F')
  dateNowDate=$(date +"%F")
  dateNowTime=$(date +"%T")
  dateTsStart=$(date -d "$d 00:00:00" +'%s')
  dateTsEnd=$(date -d "$d 23:59:59" +'%s')
  auditFileName="$dateF"'_om_'"$appType"'_audit_log.txt'

  FILE="$outputDir/$auditFileName"

  if [[ ! -e "$FILE" ]]; then
    touch "$FILE"
  else
    > "$FILE"
  fi

  touch "$tmp"

  echo "{\"version\":\"$version\", \"type\":\"$appType\", \"datetime\":\"$dateNowDate $dateNowTime\"}" >> "$FILE"

  if [[ "$appType" == "mw" ]]; then
#    echo "cd \"$vagrantPath\" && vagrant ssh -- -t -q mongoexport -d=\"$mDB\" -c=\"$mCollection\" -u=\"$mUser\" -p=\"$mPassword\" -q=\'{\"createAt\": { \"\$gte\" : \"$dateTsStart\", \"\$lt\" : \"$dateTsEnd\" } }\' --sort=\'{id: -1}\' --authenticationDatabase=admin"
    $(cd "$vagrantPath" && vagrant ssh -- -t -q mongoexport -d="$mDB" -c="$mCollection" -u="$mUser" -p="$mPassword" -q=\'{\"createAt\": { \"\$gte\" : "$dateTsStart", \"\$lt\" : "$dateTsEnd" } }\' --sort=\'{id: -1}\' --authenticationDatabase=admin >> "$tmp")
  elif [[ "$appType" == "lc" ]]; then
#    echo "docker exec -ti optimacros_db mongoexport -d=\"$mDB\" -c=\"$mCollection\" -u=\"$mUser\" -p=\"$mPassword\" -q='{\"createAt\": { \"\$gte\" : \"$dateTsStart\", \"\$lt\" : \"$dateTsEnd\" } }' --sort='{id: -1}' --authenticationDatabase=admin"
    $(docker exec -ti optimacros_db mongoexport -d="$mDB" -c="$mCollection" -u="$mUser" -p="$mPassword" -q='{"createAt": { "\$gte" : "$dateTsStart", "\$lt" : "$dateTsEnd" } }' --sort='{id: -1}' --authenticationDatabase=admin >> "$tmp")
  else
    echo "wrong application type provided"
    exit 1
  fi

  sed '1d;$d' "$tmp" >> "$FILE"
  $(rm "$tmp")

  echo "$FILE saved"
  d=$(date -I -d "$d + 1 day")
done

exit 0