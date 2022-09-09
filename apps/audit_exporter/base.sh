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
      echo "-t, --type        application type. Possible values: mw - middlework application; lc - login center"
      echo "-c, --config      config path. Path to manifest in case of MW or to .env file in case of LC contained password"
      echo "-p, --path        project path. Path to project exported from"
      echo "-s, --startDate   export starting from UTC date(Y-m-d format)"
      echo "-e, --endDate     export up to from UTC date(Y-m-d format). End date must be greater than start date"
      echo "-o, --output      output directory"
      exit 0
      ;;
    -t|--type)
      appType="$2"
      shift
      shift
      ;;
    -c|--config)
      configPath="$2"
      shift
      shift
      ;;
    -p|--path)
      projectPath="$2"
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

while [ "$d" != "$endDate" ]; do
  echo "Start export for date: $d"

  dateF=$(date -d "$d" +'%F')
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

  if [[ "$appType" == "mw" ]]; then
    mUser='admin'
    mPassword=$(cd "$projectPath" && vagrant ssh -- -t -q cat "$configPath" | grep "mongodb" -C3 | grep "$mUser" | awk -v RS='\r\n' "/$mUser/ { gsub(/[\",]/,\"\",\$2); print \$2}")
    mDB='optimacros_audit'
    mCollection='events'
    version=$(cd "$projectPath" && vagrant ssh -- -t -q cat /home/vagrant/optimacros_middlework/app/config/version.php | grep return | cut -d"'" -f 2)
    echo "{\"version\":\"$version\", \"type\":\"$appType\", \"datetime\":\"$dateF $dateT\"}" >> "$FILE"
    $(cd "$projectPath" && vagrant ssh -- -t -q mongoexport -d="$mDB" -c="$mCollection" -u="$mUser" -p="$mPassword" -q=\'{\"createAt\": { \"\$gte\" : "$dateTsStart", \"\$lt\" : "$dateTsEnd" } }\' --sort=\'{id: -1}\' --authenticationDatabase=admin >> "$tmp")
  elif [[ "$appType" == "lc" ]]; then
    mUser='login-center'
    mPassword=$(cat "$configPath" | grep 'DB_PASSWORD' | awk -v RS='\r\n' -F'=' '{print $2}')
    mDB='logincenter'
    mCollection='audit'
    version=$(cat "$configPath" | grep 'VERSION' | awk -v RS='\r\n' -F'=' '{print $2}')
    echo "{\"version\":\"$version\", \"type\":\"$appType\", \"datetime\":\"$dateF $dateT\"}" >> "$FILE"
    $(docker exec -ti optimacros_db mongoexport -d="$mDB" -c="$mCollection" -u="$mUser" -p="$mPassword" -q='{"createAt": { "$gte" : "$dateTsStart", "$lt" : "$dateTsEnd" } }' --sort='{id: -1}' --authenticationDatabase=admin >> "$tmp")
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