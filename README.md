# HOW TO

### Create docker network
```sh
docker network create -d overlay db-backup-network
```

### Clone
```sh
git clone https://github.com/rendyproklamanta/docker-mysql-backup-s3-cron
```

### Deploy
```sh
docker stack deploy --compose-file docker-compose.yaml --detach=false mariadb-backup
```
