#!/bin/sh
#redirects the standard output stream (>) to /dev/null and the standard error stream (2>&1) to the same place.
#exec > /dev/null 2>&1
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

APP="discoursio-api"
DB=$(dokku postgres:app-links $APP)
REDIS=$(dokku redis:app-links $APP)
BASE_DIR="/var/backups"
POSTGRES_DIR="postgres"
REDIS_DIR="redis"
MONGODB_DIR="mongodb"
DOCKER_DIR="docker_conf"
YMD=$(date "+%Y-%m-%d")
LAST_DB_MONGO=$(find "$BASE_DIR/$MONGODB_DIR/" -printf '%T@ %p\n' | sort -nk1 | grep discours | tail -n 1 | /bin/awk '{print $2}')

backup_database() {
  CONTAINER_ID=$(docker ps | grep $APP | /bin/awk '{print $1}')
  
  dokku postgres:export $DB | gzip -9 > "$BASE_DIR/$POSTGRES_DIR/discoursio-db-$YMD.dump.gz"
  dokku redis:export $REDIS | gzip -9 > "$BASE_DIR/$REDIS_DIR/discoursio-redis-$YMD.dump.gz"
  docker inspect $CONTAINER_ID > "$BASE_DIR/$DOCKER_DIR/docker-$APP-inspect-$YMD"
}

upload_to_storj() {
  /usr/local/bin/uplink cp --access main $BASE_DIR/$POSTGRES_DIR/discoursio-db-$YMD.dump.gz sj://discours-io-backups/$POSTGRES_DIR/
  /usr/local/bin/uplink cp --access main $BASE_DIR/$REDIS_DIR/discoursio-redis-$YMD.dump.gz sj://discours-io-backups/$REDIS_DIR/
  /usr/local/bin/uplink cp --access main $BASE_DIR/$DOCKER_DIR/docker-$APP-inspect-$YMD sj://discours-io-backups/$DOCKER_DIR/
  /usr/local/bin/uplink cp --access main $LAST_DB_MONGO sj://discours-io-backups/$MONGODB_DIR/
}

delete_local_files() {
  for DIR in $POSTGRES_DIR $REDIS_DIR $DOCKER_DIR $MONGODB_DIR; do
    echo $DIR
    OLD=$(find $BASE_DIR/$DIR -type f -mtime +3)
    for i in $OLD; do
      echo "deleting old backup files: $i"
      echo $i | xargs rm -rfv
    done
  done
}

delete_storj_files() {
  for DIR in $POSTGRES_DIR $REDIS_DIR $DOCKER_DIR $MONGODB_DIR; do
    echo $DIR
    OLD=$(/usr/local/bin/uplink ls --access main sj://discours-io-backups/$DIR/ | /bin/awk '{print $5}' | grep discours)
    for f in $OLD; do
      TODAY=$(date +%s -d $YMD)
      # Updated FILEDAY line to handle multiple naming conventions
      FILEDAY=$(echo $f | awk -F'[-.]' '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) print $i}')
      FILEDAY_SEC=$(date +%s -d $FILEDAY)
      DIFFERENCE=$(expr $TODAY - $FILEDAY_SEC)
      if [ $DIFFERENCE -gt 2592000 ];
        then
        echo "deleting old backup files: $f"
        /usr/local/bin/uplink rm --access main sj://discours-io-backups/$DIR/$f
      fi
    done
  done
}


# Main script execution
backup_database
upload_to_storj
delete_local_files
delete_storj_files