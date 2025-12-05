#!/bin/bash
set -e

dbname="alkis_sn"
dbport=5432
dbuser=postgres
dbtablespace=tbl_bigdata
CON=" -d ${dbname} -p ${dbport} -U ${dbuser}"

state=sn
tmpPath=/bigdata/tmp/alkis/

# DB erstellen #
psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$dbname' AND pid <> pg_backend_pid();" $CON
psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$dbname' AND pid <> pg_backend_pid();" $CON
dropdb --if-exists -p $dbport $dbname -U $dbuser

createdb -E UTF8 -T aaa_template_sn -D $dbtablespace -p $dbport $dbname -U $dbuser
psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON

# create tmp dir for import files to db

mkdir -p /bigdata/tmp/alkis/
rm -rf /bigdata/tmp/alkis/*

# processing alkis for state or state
cd ../alkisimport_norgis
bash alkis-import.sh ../filelists/nas_$state.lst

# rename log-file
cd ../filelists/logs
date=$(date +%Y-%m-%d)
mv "$state.log" "${state%.*}-$date.log"
