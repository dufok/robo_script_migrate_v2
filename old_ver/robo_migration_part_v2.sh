#!/bin/bash
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"
#redirects the standard output stream (>) to /dev/null and the standard error stream (2>&1) to the same place.
#exec > /dev/null 2>&1

#welcome to robo_migrate 1a
#created by dufok (duffokin@gmail.com)
#the first part live in server testip.discours.io in /root/robo_script dir

APP="discoursio-api"
NEW_PATH="/root"
YMD=$(date "+%Y-%m-%d_%H-%M")
OLD_DB=$(dokku postgres:app-links $APP)
DUMP=$(find $NEW_PATH -name "*.dump.gz" -printf "%T@ %p\n" | sort -n | tail -1 | cut -d" " -f2-)
NEW_DB=$(basename $DUMP | sed 's/\.dump\.gz//')



#Create new db with actual data

create_new_db(){
dokku postgres:create $NEW_DB
	DSN_NEW_DB=$(echo "$(dokku postgres:info $NEW_DB --dsn)" | sed 's/postgres/postgresql/')
	gunzip -c $DUMP | dokku postgres:import $NEW_DB
}


#migrate db in app

migrate_db(){
	dokku ps:stop $APP
	dokku config:unset $APP DATABASE_URL --no-restart
	dokku config:set $APP DATABASE_URL=$DSN_NEW_DB --no-restart
	dokku postgres:unlink $OLD_DB $APP
	dokku postgres:destroy $OLD_DB -f
	dokku postgres:link $NEW_DB $APP -a "MIGRATION_DATABASE"
	dokku config:unset $APP MIGRATION_DATABASE_URL --no-restart
	dokku ps:start $APP
}

#delete working dump files

clean(){
	rm -rf $DUMP
}

create_new_db
migrate_db
clean

