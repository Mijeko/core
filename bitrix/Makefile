PROJECT_NAME=sinar
ROOT_DIR=application
LOCAL_DIR=$(ROOT_DIR)/local
COMPOSER_DIR=$(LOCAL_DIR)/core
UPLOAD_DIR=upload

UPLOAD_PATH=$(ROOT_DIR)/$(UPLOAD_DIR)

ASSETS=$(LOCAL_DIR)/assets
MARKUP=markup

DB_NAME=sinar
DB_HOST=mariadb
DB_USER=root
DB_PWD=root
DB_BACKUP_DIR=docker/db/
DB_BACKUP_FILE=stable_1_1.sql.gz
DB_START_FILE=start.sql.gz
DB_BACKUP_PATH=$(DB_BACKUP_DIR)$(DB_BACKUP_FILE)
DB_START_FILE_PATH=$(DB_BACKUP_DIR)$(DB_START_FILE)

webpack: webpack-clear-assets clear-assets webpack-build webpack-copy
deploy-local: pull config-local composer-install cache
deploy-test: pull config-test composer-install cache
deploy-docker: pull config-docker docker-composer-install cache

docker: config-docker docker-build docker-up cache

composer-install:
	cd $(COMPOSER_DIR) && composer install

docker-composer-install:
	docker exec -ti $(shell docker ps --filter name=$(PROJECT_NAME)-php-fpm -a -q) sh -c "cd $(COMPOSER_DIR) && composer install"

push:
	git add . && git commit -m "update" && git push

pull:
	git pull

cache:
	rm -rf $(ROOT_DIR)/bitrix/cache/
	rm -rf $(ROOT_DIR)/bitrix/managed_cache/
	rm -rf $(ROOT_DIR)/bitrix/stack_cache/

mysqldump:
	mysqldump -h $(DB_HOST) -u $(DB_USER) -p$(DB_PWD) $(DB_NAME) | gzip > $(DB_BACKUP_PATH)

docker-mysqldump:
	docker exec -ti $(shell docker ps --filter name=php-fpm -a -q) sh -c "mysqldump -h $(DB_HOST) -u $(DB_USER) -p$(DB_PWD) $(DB_NAME) | gzip > $(DB_BACKUP_PATH)"

dumpmv:
	mv $(DB_BACKUP_PATH) $(DB_START_FILE_PATH)

mysqlimport: drop import

drop:
	mysql -h $(DB_HOST) -u $(DB_USER) -p$(DB_PWD) $(DB_NAME) --execute="drop database $(DB_NAME); CREATE DATABASE $(DB_NAME) DEFAULT CHARACTER SET utf8 COLLATE UTF8_UNICODE_CI;"

import:
	gunzip <  $(DB_BACKUP_PATH) | mysql -h $(DB_HOST) -u $(DB_USER) -p$(DB_PWD) $(DB_NAME)

webpack-build:
	cd $(MARKUP) && npm run build

webpack-clear-assets:
	rm -rf $(MARKUP)/build

clear-assets:
	rm -rf $(ASSETS)

docker-webpack-install:
	docker exec -ti $(shell docker ps --filter name=$(PROJECT_NAME)-markup -a -q) sh -c "cd $(MARKUP) && npm install"

docker-webpack-build:
	docker exec -ti $(shell docker ps --filter name=$(PROJECT_NAME)-markup -a -q) sh -c "cd $(MARKUP) && npm run build"

docker-webpack: clear-assets docker-webpack-install docker-webpack-build

webpack-copy:
	cp -R $(MARKUP)/build/js $(ASSETS)
	cp -R $(MARKUP)/build/assets/images $(ASSETS)
	cp -R $(MARKUP)/build/css $(ASSETS)

config-local:
	cp $(ROOT_DIR)/bitrix/.settings.local.php $(ROOT_DIR)/bitrix/.settings.php
	cp $(ROOT_DIR)/bitrix/php_interface/dbconn.local.php $(ROOT_DIR)/bitrix/php_interface/dbconn.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.local.php $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect.local.php $(ROOT_DIR)/bitrix/php_interface/after_connect.php
	cp $(ROOT_DIR)/.htaccess.local $(ROOT_DIR)/.htaccess

config-test:
	cp $(ROOT_DIR)/bitrix/.settings.test.php $(ROOT_DIR)/bitrix/.settings.php
	cp $(ROOT_DIR)/bitrix/php_interface/dbconn.test.php $(ROOT_DIR)/bitrix/php_interface/dbconn.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.test.php $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect.test.php $(ROOT_DIR)/bitrix/php_interface/after_connect.php
	cp $(ROOT_DIR)/.htaccess.test $(ROOT_DIR)/.htaccess

config-docker:
	cp $(ROOT_DIR)/bitrix/.settings.docker.php $(ROOT_DIR)/bitrix/.settings.php
	cp $(ROOT_DIR)/bitrix/php_interface/dbconn.docker.php $(ROOT_DIR)/bitrix/php_interface/dbconn.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.docker.php $(ROOT_DIR)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT_DIR)/bitrix/php_interface/after_connect.docker.php $(ROOT_DIR)/bitrix/php_interface/after_connect.php
	cp $(ROOT_DIR)/.htaccess.docker $(ROOT_DIR)/.htaccess

docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-rebuild: docker-mysqldump docker-stop dumpmv docker

docker-stop:
	docker stop $(shell docker ps --filter name=$(PROJECT_NAME) -q)
	docker rm $(shell docker ps --filter name=$(PROJECT_NAME) -a -q)

# В архиве лежат фотки из готового решения.
upload:
	rm -rf $(UPLOAD_PATH) && cd $(ROOT_DIR) && unzip upload.zip && chmod -R 0777 $(UPLOAD_DIR)