# Для локальной разработки!
версия ядра в импокаре = 16... <br>
остальное ищи в /Makefile

## Порядок разработки в Windows
Если вы работаете в Windows, то требуется установить виртуальную машину, тестировалось на Ubuntu 18.04.
Ваш рабочий проект должен хранится в двух местах, первое - локальная папка с проектами на хосте (открывается в IDE), второе - виртуальная машина
(например ```/var/www/bitrix```). Проект на хосте мапится в IDE к гостевой OC.

## Автоматическая установка  
```
docker-compose up -d
cat ../public/archive.sql | docker exec -i db /usr/bin/mysql -u root -p123 bitrix

# or set impocar host to ~/.ssh/config and

ssh impocar "mysqldump -u impocar -p'<mysql_password>' --single-transaction impocar | gzip -c" | gunzip -c | docker exec -i db /usr/bin/mysql -u root -p123 bitrix
```
Если у вас мак, удалите строчку `/etc/localtime:/etc/localtime/:ro` из docker-compose

По умолчнию используется nginx, php7, mysql. Настройки можно изменить в файле ```.env```. Также можно задать путь к каталогу с сайтом и параметры базы данных MySQL.


```
PHP_VERSION=php71          # Версия php 
WEB_SERVER_TYPE=nginx      # Веб-сервер nginx/apache
DB_SERVER_TYPE=mysql       # Сервер базы данных mysql/percona
MYSQL_DATABASE=bitrix      # Имя базы данных
MYSQL_USER=bitrix          # Пользователь базы данных
MYSQL_PASSWORD=123         # Пароль для доступа к базе данных
MYSQL_ROOT_PASSWORD=123    # Пароль для пользователя root от базы данных
INTERFACE=0.0.0.0          # На данный интерфейс будут проксироваться порты
SITE_PATH=/var/www/bitrix  # Путь к директории Вашего сайта

```

### Запустите bitrixdock
```
docker-compose up -d
```
Чтобы проверить, что все сервисы запустились посмотрите список процессов ```docker ps```.  
Посмотрите все прослушиваемые порты, должны быть 80, 11211, 9000 ```netstat -plnt```.  
Откройте IP машины в браузере.

http://localhost - для разработки

## Примечание
- По умолчанию стоит папка ```/var/www/bitrix/```
- В настройках подключения требуется указывать имя сервиса, например для подключения к базе нужно указывать "db", а не "localhost". Пример [конфига](configs/.settings.php)  с подклчюением к mysql и memcached.
- Для загрузки резервной копии в контейнер используйте команду: ```cat /var/www/bitrix/backup.sql | docker exec -i mysql /usr/bin/mysql -u root -p123 bitrix```



# Пример
Пример реального Docker проекта для Bitrix - Single Node    
https://github.com/bitrixdock/production-single-node   

Ещё один проект с php7 и отправкой почты, взят с боевого проекта, вырезаны пароли, сертификаты и тп   
https://github.com/bitrixdock/bitrixdock-production

Реальные проекты на основе этих проектов работают годами без проблем если их не трогать )
![Alt text](assets/Clip2net_200727170318.png?raw=true "BitrixDock")
