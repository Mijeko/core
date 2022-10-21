#!/bin/bash
#
# Bitrix GT configuration script
# https://firstvds.ru/hosting/bitrix
#
####################################

ARGV="$@"

if [ "x$ARGV" = "x" ] || [ "x$ARGV" = "xusage" ] || [ "x$ARGV" = "xhelp" ] || [ "x$ARGV" = "x--help" ]; then
  cat << EOF
  Usage: $0 addsite | addsslsite | getssl example.com [default]

  Examples: 
    Create the new http site in /var/www/example.com:
    $0 addsite example.com

    Create the new https site in /var/www/example.com:
    $0 addsslsite example.com

    Add https to /var/www/html (default site):
    $0 addsslsite example.com default
    
    Get Let's encrypt certificate for /var/www/html (default site):
    $0 getssl example.com default

    Get Let's encrypt certificate for site in /var/www/example.com:
    $0 getssl example.com

    Get Let's encrypt wildcard certificate for example.com with DNSmanager integration:
    $0 getsslwildcard dnsmanager_user dnsmanager_password example.com
    
    Create DNS domain masterzone example.com point to ipaddress 10.10.10.10 in the DNSmanager:
    $0 adddnsmanager dnsmanager_user dnsmanager_password 10.10.10.10 example.com
    
    Create the new MySQL database:
    $0 adddb dbname username password
    
    Change MySQL user password:
    $0 chmysqlpass username password
    
    Install pure-ftpd server for access to /var/www | add new ftp unixsystem user:
    $0 addftpuser username password
    
    Download maintenance script for manage bitrix website (bitrixsetup.php restore.php bitrix_server_test.php pusti.php):
    $0 getscript example.com | default scriptname
     Examples:
      $0 getscript default pusti
      $0 getscript example.com setup
      $0 getscript example.com restore
      $0 getscript example.com servertest
    
EOF
 exit 1
fi

###
# nginx webserver restart helper with configtest
restart_nginx () {
echo -e "Try to restart nginx ..."
nginx -t
if [[ $? == 0 ]]; then
 systemctl restart nginx.service
else
 exit 1;
fi
}

###
# create http host
add_site () {
echo "Setting up $1 in nginx"

if [ -f /etc/nginx/bx/site_enabled/$1.conf ]; then
    echo "ERROR : Configuration file /etc/nginx/bx/site_enabled/$ARGV.conf already exist"
    exit 1
fi

echo "Create directory /var/www/$1 for new site"
mkdir /var/www/$1 && chown apache:apache /var/www/$1

echo "Creating nginx configuraion file /etc/nginx/bx/site_enabled/$1.conf"
cat > /etc/nginx/bx/site_enabled/$1.conf << EOF
server {
	listen 80;
	server_name DOMAIN www.DOMAIN;
	server_name_in_redirect off;

	error_log /var/log/nginx/DOMAIN.error.log;
	access_log /var/log/nginx/DOMAIN.access.log;

	fastcgi_param   X-Real-IP        \$remote_addr;
        fastcgi_param   X-Forwarded-For  \$proxy_add_x_forwarded_for;
        fastcgi_param   Host \$host:80;

	set \$proxyserver	"http://127.0.0.1:9000";
	set \$docroot		"/var/www/DOMAIN";

	index index.php;
	root /var/www/DOMAIN;

	# Redirect to ssl if need
	#if (-f /var/www/DOMAIN/.htsecure) { rewrite ^(.*)$ https://\$host\$1 permanent; }

	# Include parameters common to all websites
	include bx/conf/bitrix.conf;

	# Include server monitoring locations
	include bx/server_monitor.conf;
	}
EOF

sed -i "s/DOMAIN/$1/g" /etc/nginx/bx/site_enabled/$1.conf

restart_nginx
}


###
# create https host
add_ssl_site () {
echo "Setting up $1 SSL in nginx"

if [ -f /etc/nginx/bx/site_enabled/ssl-$1.conf ]; then
    echo "ERROR : Configurationg file /etc/nginx/bx/site_enabled/ssl-$1.conf already exist"
    exit 1
fi

echo "Genereating self-signed certificate in /etc/nginx/ssl/$1-dummy.{crt/key} ..."
[ -d /etc/nginx/ssl ] || mkdir /etc/nginx/ssl

openssl req -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/$1-dummy.key -out /etc/nginx/ssl/$1-dummy.crt -x509 -days 3650 -subj "/C=XX/ST=XX/L=XX/O=XX/OU=XX/CN=$1/emailAddress="root@example.com

echo "Creating nginx config file /etc/nginx/bx/site_enabled/ssl-$1.conf"
cat > /etc/nginx/bx/site_enabled/ssl-$1.conf << EOF
server {
	listen 443 ssl http2;
	server_name DOMAIN www.DOMAIN;
	server_name_in_redirect off;

	error_log /var/log/nginx/DOMAIN.error.log;
	access_log /var/log/nginx/DOMAIN.access.log;

	ssl_certificate		/etc/nginx/ssl/$1-dummy.crt;
	ssl_certificate_key	/etc/nginx/ssl/$1-dummy.key;

	ssl_protocols TLSv1.2;
	ssl_prefer_server_ciphers on;
	ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;
	#add_header Strict-Transport-Security max-age=15768000;

	fastcgi_param   X-Real-IP        \$remote_addr;
        fastcgi_param   X-Forwarded-For  \$proxy_add_x_forwarded_for;
        fastcgi_param   Host \$host:443;

	set \$proxyserver	"http://127.0.0.1:9000";
	set \$docroot		"/var/www/DOMDIR";

	index index.php;
	root /var/www/DOMDIR;
       
        # SEO Redirect non-www to www
        #if (\$host != 'www.DOMAIN') { rewrite ^/(.*)$ https://www.DOMAIN/\$1 permanent; } 
        
	# Include parameters common to all websites
	include bx/conf/bitrix.conf;

	# Include server monitoring locations
	include bx/server_monitor.conf;
	}
EOF

#check default or new host added
if [ "$2" = "default" ]; then
 echo "Using /var/www/html documentroot"
 sed -i "s/DOMDIR/html/g" /etc/nginx/bx/site_enabled/ssl-$1.conf
 else
 echo "Using /var/www/$1 documentroot"
 sed -i "s/DOMDIR/$1/g" /etc/nginx/bx/site_enabled/ssl-$1.conf
fi

sed -i "s/DOMAIN/$1/g" /etc/nginx/bx/site_enabled/ssl-$1.conf

restart_nginx
}

###
# install certbot if not installed
install_certbot () {
rpm -q certbot &> /dev/null
if [ $? -eq 0 ]; then
    echo "Package certbot is installed, OK"
else
    echo "Package certbot is not installed, installing certbot via yum"
    yum -y install certbot python2-certbot-nginx
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

 echo "Cron job for certificates renew was added to /etc/cron.d/certbot"
 echo "17 */12 * * * root /usr/bin/certbot --nginx renew --quiet --allow-subset-of-names" > /etc/cron.d/certbot
fi
}

###
# install dig utility
install_bind-utils () {
rpm -q bind-utils &> /dev/null
if [ $? -eq 0 ]; then
    echo "Package bind-utils is installed, OK"
else
    echo "Package bind-utils is not installed, installing bind-utils via yum"
    yum -y install bind-utils
    rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
fi
}

###
# get letsencrypt certificate
get_letsencrypt () {

# check cerbot installation
install_certbot

# check default or new host added
if [ "$2" = "default" ]; then
 echo "Using /var/www/html documentroot"
 DOCROOT="/var/www/html"
 else
 echo "Using /var/www/$1 documentroot"
 DOCROOT="/var/www/$1"
fi

echo "Attempt to dry-run certificate..."
certbot certonly --expand -d $1 -d www.$1 -w $DOCROOT -n --webroot --agree-tos --email sslmaster@$1 --dry-run 

# check and get certificate
if [[ $? == 0 ]]; then
echo -e "\nDry-run success! Try to get certificate..."
certbot certonly --expand -d $1 -d www.$1 -w $DOCROOT -n --webroot --agree-tos --email sslmaster@$1
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

cat << EOF
Please edit /etc/nginx/bx/site_enabled/ssl-$1.conf and change cerificate lines to:

ssl_certificate      /etc/letsencrypt/live/$1/fullchain.pem;
ssl_certificate_key  /etc/letsencrypt/live/$1/privkey.pem; 

EOF

else
 echo -e "\nERROR : Dry-run fail! You should fix this"
 exit 1
fi
}


###
# get wildcard letsencrypt certificate with DNSmanager integration
get_le_wildcard () {

# check cerbot and dig installation
install_certbot
install_bind-utils

dnsuser=$1
dnspass=$2
domain=$3

echo "Download DNSmanager hooks written by SubGANs"
wget -O /opt/lew_dnsmgr_hook.sh http://dl.ispsystem.info/bitrix-gt/le-hooks/lew_dnsmgr_hook.sh && chmod +x /opt/lew_dnsmgr_hook.sh
wget -O /opt/lew_dnsmgr_hook_del.sh http://dl.ispsystem.info/bitrix-gt/le-hooks/lew_dnsmgr_hook_del.sh && chmod +x /opt/lew_dnsmgr_hook_del.sh

# change authdata in lew_dnsmgr_hook.sh
sed -i "s/_DNSUSER_/$dnsuser/" /opt/lew_dnsmgr_hook.sh
sed -i "s/_DNSUSERPASS_/$dnspass/" /opt/lew_dnsmgr_hook.sh

echo "Attempt to dry-run certificate..."
certbot certonly --manual --manual-public-ip-logging-ok --agree-tos --email sslmaster@$domain --no-eff-email --preferred-challenges=dns -d *.$domain -d $domain --manual-auth-hook /opt/lew_dnsmgr_hook.sh --manual-cleanup-hook /opt/lew_dnsmgr_hook_del.sh --dry-run
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

echo "Dry-run success! Try to get certificate..."
certbot certonly --manual --manual-public-ip-logging-ok --agree-tos --email sslmaster@$domain --no-eff-email --preferred-challenges=dns -d *.$domain -d $domain --manual-auth-hook /opt/lew_dnsmgr_hook.sh --manual-cleanup-hook /opt/lew_dnsmgr_hook_del.sh

}

###
# Create new domain name in the DNSmanager
add_dnsmanager () {

DNSMGR="https://msk-dns2.hoztnode.net/manager/dnsmgr"
DNSUSER=$1
DNSUSERPASS=$2
DOMAINIP=$3
DOMAINNAME=$4

res=$(curl -ks "$DNSMGR?authinfo=$DNSUSER:$DNSUSERPASS&out=text&func=domain.edit&name=$DOMAINNAME&ip=$DOMAINIP&dtype=master&sok=ok")
if [[ `echo "$res" | grep OK` ]]; then
    echo "OK : Domain $4 created"
else
    echo "ERROR : ($(echo "$res"))" 
    exit
fi
}

###
# MySQL server support
add_database () {
database=$1
user=$2
password=$3
echo "creating new database $database identified by login/password"
mysql -N -e "CREATE DATABASE \`$database\`"
mysql -e "GRANT ALL PRIVILEGES ON \`$database\`.* TO '$user'@localhost IDENTIFIED BY '$password'"
mysql -e "FLUSH PRIVILEGES"
}

ch_mysqlpass () {
user=$1
password=$2
mysql -e "ALTER USER '$user'@localhost IDENTIFIED BY '$password'"
mysql -e "FLUSH PRIVILEGES"
}

###
# FTP server support
add_ftpuser () {
# check is pure-ftpd installed
rpm -q pure-ftpd &> /dev/null
if [ $? -eq 0 ]; then
   echo "Package pure-ftpd is installed, OK"
else
   echo "Package pure-ftpd is not installed, installing pure-ftpd via yum ..."
   yum -y install pure-ftpd
   rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

   echo "Opening ports tcp 20-21 and 40900-40999 in firewalld for passive ftp service"
   firewall-cmd --permanent --add-port=20-21/tcp
   firewall-cmd --permanent --add-port=40900-40999/tcp 
   firewall-cmd --reload
   
   echo "Configure and start pure-ftpd daemon"
   sed -i "s/MinUID/#MinUID/" /etc/pure-ftpd/pure-ftpd.conf

cat >> /etc/pure-ftpd/pure-ftpd.conf << EOF

# added by admin.sh
MinUID 48
PassivePortRange 40900 40999
EOF

   systemctl enable pure-ftpd
   systemctl start pure-ftpd.service
fi
   echo "Add system user $1 for /var/www ftp access"
   adduser $1 -o -u 48 -g 48 -M -N -s /bin/date -d /var/www
   echo "$1:$2" | chpasswd
}

###
# Download bitrix scripts for setup/restore
get_bitrix_script () {

if [ "$1" = "default" ]; then
 echo "Using /var/www/html documentroot"
 DOCROOT="/var/www/html"
 else
 echo "Using /var/www/$1 documentroot"
 DOCROOT="/var/www/$1"
fi

case $2 in
     setup)
       wget -O $DOCROOT/bitrixsetup.php http://www.1c-bitrix.ru/download/scripts/bitrixsetup.php && chown apache:apache $DOCROOT/bitrixsetup.php  
        ;;
     restore)
       wget -O $DOCROOT/restore.php http://www.1c-bitrix.ru/download/scripts/restore.php && chown apache:apache $DOCROOT/restore.php
        ;;
     servertest)
       wget -O $DOCROOT/bitrix_server_test.php http://www.1c-bitrix.ru/download/scripts/bitrix_server_test.php && chown apache:apache $DOCROOT/bitrix_server_test.php
        ;;
     pusti)
       wget -O $DOCROOT/pusti.php http://dl.ispsystem.info/bitrix-gt/pusti.php && chown apache:apache $DOCROOT/pusti.php
        ;;
     *)
       echo "ERROR : Unknown agrument $2, run $0 for get help" ; exit 1;
      ;;
esac
}

###
# argument selector
case $1 in
     addsite)
      add_site $2
       ;;
     addsslsite)
       add_ssl_site $2 $3
       ;;
     getssl)
       get_letsencrypt $2 $3
       ;;
     getsslwildcard)
       get_le_wildcard $2 $3 $4
       ;;
     adddnsmanager)
       add_dnsmanager $2 $3 $4 $5
       ;;
     adddb)
       add_database $2 $3 $4
       ;;
     chmysqlpass)
       ch_mysqlpass $2 $3
       ;;
     addftpuser)
       add_ftpuser $2 $3
       ;;
     getscript)
       get_bitrix_script $2 $3
       ;;
     *)
       echo "ERROR : Unknown agrument $1, run $0 for get help" ; exit 1;
      ;;
esac
