ROOT=application
ASSETS=$(ROOT)/local/assets

webpack: webpack-clear-assets webpack-build webpack-copy
deploy-local: pull config-local cache
deploy-test: pull config-test cache

push:
	git add . && git commit -m "update" && git push

pull:
	git pull

cache:
	rm -rf $(ROOT)/bitrix/cache/
	rm -rf $(ROOT)/bitrix/managed_cache/
	rm -rf $(ROOT)/bitrix/stack_cache/

webpack-build:
	cd local/markup && npm run build

webpack-clear-assets:
	rm -rf local/assets

webpack-copy:
	cp -R local/markup/build/js $(ASSETS)
	cp -R local/markup/build/assets/images $(ASSETS)
	cp -R local/markup/build/css $(ASSETS)

config-local:
	cp $(ROOT)/bitrix/.settings.local.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.local.php $(ROOT)/bitrix/php_interface/dbconn.php
	cp $(ROOT)/bitrix/php_interface/after_connect_d7.local.php $(ROOT)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT)/bitrix/php_interface/after_connect.local.php $(ROOT)/bitrix/php_interface/after_connect.php
	cp $(ROOT)/.htaccess.local $(ROOT)/.htaccess

config-test:
	cp $(ROOT)/bitrix/.settings.test.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.test.php $(ROOT)/bitrix/php_interface/dbconn.php
	cp $(ROOT)/bitrix/php_interface/after_connect_d7.test.php $(ROOT)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT)/bitrix/php_interface/after_connect.test.php $(ROOT)/bitrix/php_interface/after_connect.php
	cp $(ROOT)/.htaccess.test $(ROOT)/.htaccess

config-docker:
	cp $(ROOT)/bitrix/.settings.docker.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.docker.php $(ROOT)/bitrix/php_interface/dbconn.php
	cp $(ROOT)/bitrix/php_interface/after_connect_d7.docker.php $(ROOT)/bitrix/php_interface/after_connect_d7.php
	cp $(ROOT)/bitrix/php_interface/after_connect.docker.php $(ROOT)/bitrix/php_interface/after_connect.php
	cp $(ROOT)/.htaccess.docker $(ROOT)/.htaccess

docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker: config-docker docker-build docker-up cache