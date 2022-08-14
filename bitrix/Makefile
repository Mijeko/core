ASSETS=application/local/assets
ROOT=application
pull:
	git pull

push:
	git add . && git commit -m "update" && git push

config-docker:
	cp $(ROOT)/bitrix/.settings.docker.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.docker.php $(ROOT)/bitrix/php_interface/dbconn.php

config-prod:
	cp $(ROOT)/bitrix/.settings.prod.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.prod.php $(ROOT)/bitrix/php_interface/dbconn.php

config-local:
	cp $(ROOT)/bitrix/.settings.local.php $(ROOT)/bitrix/.settings.php
	cp $(ROOT)/bitrix/php_interface/dbconn.local.php $(ROOT)/bitrix/php_interface/dbconn.php

cache:
	rm -rf $(ROOT)/bitrix/cache/
	rm -rf $(ROOT)/bitrix/managed_cache/

webpack-build:
	cd markup && npm run build

webpack-copy:
	rm -rf $(ASSETS)
	cp -R markup/build/js $(ASSETS)
	cp -R markup/build/css $(ASSETS)
	cp -R markup/build/assets/images $(ASSETS)
	cp -R markup/build/assets/fonts $(ASSETS)

docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker: config-docker docker-build docker-up
webpack: webpack-build webpack-copy
deploy: pull config-prod cache
deploy-local: pull config-local cache
deploy-docker: pull config-docker cache