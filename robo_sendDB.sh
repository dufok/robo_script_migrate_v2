#!/bin/bash

export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

APP="discoursio-api"
SSH_KEY="/root/.ssh/id_rsa"
YMD=$(date "+%Y-%m-%d")
DUMP_PATH="/var/lib/dokku/data/storage/discoursio-api/migration/dump"
DATA_PATH="/var/lib/dokku/data/storage/discoursio-api/migration/data"
SCRIPT_PATH="/root/robo_script"
MONGO_DB_PATH="/var/backups/mongodb"
POSTGRES_DB_PATH="/var/backups/postgres"
CONTAINER_ID=$(docker ps | grep "$APP" | /bin/awk '{print $1}')
OLD_DB=$(dokku postgres:app-links "$APP")
NEW_DB="discoursio-db-new-$YMD"
DSN_OLD_DB=$(dokku config:get "$APP" DATABASE_URL)
LAST_DB_MONGO=$(find "$MONGO_DB_PATH" -printf '%T@ %p\n' | sort -nk1 | grep discours | tail -n 1 | /bin/awk '{print $2}')
LAST_DB_POSTGRES=$(find "$POSTGRES_DB_PATH" -printf '%T@ %p\n' | sort -nk1 | grep discours | tail -n 1 | /bin/awk '{print $2}')
NEW_HOST="5.255.97.70"
NEW_PATH="/root/."
NEW_PATH_MONGO="/var/lib/dokku/data/storage/migrator/dump/"

send_postgres_dump() {
echo "send postgres.dump to $NEW_HOST"
scp -i "$SSH_KEY" -r "$LAST_DB_POSTGRES" "root@$NEW_HOST:$NEW_PATH"
}

send_mongo_dump() {
echo "send mongo.dump to $NEW_HOST"
scp -i "$SSH_KEY" -r "$LAST_DB_MONGO" "root@$NEW_HOST:$NEW_PATH_MONGO"
}

#send_postgres_dump
send_mongo_dump