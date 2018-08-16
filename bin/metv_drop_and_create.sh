#!/bin/sh

dbname="mv_saudi_gwpme"
host="localhost"
metv="/d1/pmemet/metviewer"
mvuser="mvuser"
mvpass="ahquunoghahch8layeiThaig"

# Drop the database
echo "CALLING: mysql -h${host} -u${mvuser} -p${mvpass} -e'drop database ${dbname};'"
mysql -h${host} -u${mvuser} -p${mvpass} -e"drop database ${dbname};"

# Create the database
echo "CALLING: mysql -h${host} -u${mvuser} -p${mvpass} -e'create database ${dbname};'"
mysql -h${host} -u${mvuser} -p${mvpass} -e"create database ${dbname};"

# Apply the METViewer schema
echo "CALLING: mysql -h${host} -u${mvuser} -p${mvpass} ${dbname} < ${metv}/sql/mv_mysql.sql"
mysql -h${host} -u${mvuser} -p${mvpass} ${dbname} < ${metv}/sql/mv_mysql.sql
