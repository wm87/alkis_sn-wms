#!/bin/bash
set -e

# Deklaration
export template="template_postgis"
export dbname="aaa_template_sn"
export dbport="5432"
export dbuser="postgres"
export dbtablespace="pg_default"

export CON=" -d ${dbname} -p ${dbport} -U ${dbuser}"

# 1. Vorbereitungen für template_postgis
psql -p $dbport -U $dbuser -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '$template' AND pid <> pg_backend_pid();"
dropdb --if-exists -p $dbport -U $dbuser $template

# 2. template_postgis erstellen und PostGIS installieren
createdb -E UTF8 -D $dbtablespace -p $dbport -U $dbuser $template
psql -d $template -p $dbport -U $dbuser -c "CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;"
psql -d $template -p $dbport -U $dbuser -c "CREATE EXTENSION IF NOT EXISTS postgis_topology SCHEMA public;"
psql -d $template -p $dbport -U $dbuser -c "VACUUM FULL;"
psql -d postgres -p $dbport -U $dbuser -c "UPDATE pg_database SET datistemplate = TRUE WHERE datname = '$template';"

# 3. Ziel-DB aaa_template_sn vorbereiten
psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = '$dbname' AND pid <> pg_backend_pid();" -p $dbport -U $dbuser
dropdb --if-exists -p $dbport -U $dbuser $dbname

# 4. aaa_template_sn erstellen auf Basis von template_postgis
createdb -E UTF8 -T $template -D $dbtablespace -p $dbport -U $dbuser $dbname

# 5. Weitere Konfiguration und Import
psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON
psql -f alkis-schema_25833.sql $CON
psql -c "VACUUM FULL;" $CON
