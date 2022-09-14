#### Audit export scripts

**core script** - base.sh. Allow to export audit from middlework or login center with a provided date range. 
Script creates files with export per 1 day based on server date in a provided folder.
use -h or --help to read about all input attributes.
examples:

./base.sh -t "lc" -p "/om/optimacros/login-center/.env" -s "2022-09-08" -e "2022-09-09" -o "/mnt/export/some/folder"
./base.sh -t "mw" -p "/path/to/manifest.json" -v "/path/to/vagrant/container" -s "2022-08-01" -e "2022-09-09" -o "/some/output/dir"

**used env variables** - audit_export.sh
used to simplify export with saving input to .env file
the only one required attribute - path to .env
.env can be created based on .env.example file.
To do export for current day(for example in a cron) - leave env parameters START_DATE, END_DATE empty.
example:

./audit_export.sh --env ".env"