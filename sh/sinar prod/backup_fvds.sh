#!/bin/bash
#Author S.Avdeev
#Скрипт для бекапа. Сначала делаем новый, потом удаляем старый.
#В крон добавляем задания с параметрами, первый параметр - количество копий, второй параметр - тип копий (ежедневная - day, еженедельная -week, ежемесячная - month). При желании вместо подавления вывода можно направить вывод скрипта в файл, таким образом получить вполне понятный лог.

pg='0' #бекапим pg, убедись что есть запись "local all postgres trust" в pg_hba.conf
mysql='1' #бекапим mysql
mysqlUser='root' #Имя mysql пользователя 
mysqlPass='4eVz1V2HZXuq' #Пароль mysql юзера
workDir='/root/backup/work_fvds/' #Рабочая дира скрипта, в конце должен быть слеш.
backup='/var/www/' #Путь который бекапим, тут должна быть одна директория\файл. 
useLocalStorage='0' #Хранить ли локальную (если хотим хранить и локально и на ftp)
useFtp='1' #Заливать ли на FTP
useYadsk='0' #Заливать ли на yandex, первый запуск в этом случае нужно сделать вручную (чтобы получить токен). CentOS неподерживается из за древнего wget.
yalogin='' #логин от яндекса
usePassiveMode='0'
HOST='wdc-backup5.ispsystem.net' #FTPserver
USER='ftp4436046' #FTPuser
PASSWD='o5407L3Bj5CO' #FTPpass
ftpdestdir='/sinar' #директория на ftp сервере, чтобы делать копии в корень, оставь переменную пустой. Директория должна быть предварительно создана руками. 
mail='' #Email для уведомлений
sliceSize='102400' #При использовании ftp архив бъется на слайсы. Размер слайса в килобайтах, использовать приставки нельзя.
ni='0' #Приоритет выполнения tar (от 19 до -20).

#=============================Все написанное ниже менять только на свой страх и риск ===============
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
count=$1
type=$2
date=`date +%d-%m-%Y`
wd=`echo $workDir|sed 's/^\///;s/\/$//'`
used=`df /|awk '{print $3}'|tail -n 1`
freespace=`df /|awk '{print $4}'|tail -n 1`
sqlnodelete=0
sqlnodump=0
tarnodelete=0
tmpnodel=0
[ -d $workDir ] || mkdir -vp $workDir

if [ $useYadsk -eq "1" ]
then
[[ $(wget -V|head -n1|grep -Eo '[0-9.]*'|head -n1|cut -d'.' -f 2) -lt 16 ]] && useYadsk=0 && echo 'wget менее чем 1.16 не позволяет грузить на yandex, загрузка будет отменена.'
fi

if [ $ftpdestdir ]
then
	ftpdestdir="cd $ftpdestdir"
fi

let count2=$count-1
set -o pipefail #Фикс кода завершения пайпы
ppid=`ps -o ppid= $$`
if ! [ $usePassiveMode -eq 0 ]
then
usePassiveMode=passive
else
unset usePassiveMode
fi
if [ $useFtp -eq "1" ]
then
rm -f $workDir'tmp/ftpload.log'
fi

cat <<EOF >/root/extract.sh
#!/bin/bash
#Extract script.
#Нужно малость переделать для возможности распаковки архива не с первого тома (для случаев когде не все архивы есть).

if [ \$1 ] && [ -f \$1 ]
then
         tar -M -xf \$1 --volno-file=/tmp/volno -F "\$BASH_SOURCE tar" -C ./
fi

if [ \$1 ] && [ \$1 == "tar" ]
then
        name=\$(echo \$TAR_ARCHIVE|sed 's/\.[0-9]*$//')
        if [ -f \$name.\$TAR_VOLUME ]
        then
		echo \$name.\$TAR_VOLUME
                echo \$name.\$TAR_VOLUME >&\$TAR_FD
                else
		echo "extracted \$(cat /tmp/volno) archives."
                rm -f /tmp/volno
                exit 1
        fi
fi
EOF
chmod +x /root/extract.sh
#=============================#Функции==================================================================

##REST
oauth() {
	#Получаем oauth ключ, из файла с ранее полученным токеном или получаем новый токен.
	tokenpath=$1
	yalogin=$2
	if [[ -f $tokenpath ]] && [[ $(cat $tokenpath) ]]
	then
		token=$(cat $tokenpath)
	else
		clid='c143dba84dd14ab58236c526e17bff26'
		clsec='946931b0bf674955bf8e83816f0a043f'
		b64=$(echo $clid:$clsec|base64)
		devid=$(cat /dev/urandom | base64 | head -c 12)
		devname=$(hostname)
		echo "Перейдите по ссылке и получите код:" 
		echo "https://oauth.yandex.ru/authorize?response_type=code&client_id=c143dba84dd14ab58236c526e17bff26&device_id=$devid&device_name=$devname&login_hint=$yalogin"
		echo "После введите код здесь:"
		read code
		token=$(wget  -qO- --post-data="grant_type=authorization_code&code=$code&client_id=$clid&client_secret=$clsec" "https://oauth.yandex.ru/token?grant_type=authorization_code")
		echo "raw $token"
		token=$(echo $token|cut -d',' -f2|cut -d':' -f2|grep -Eo '[a-zA-Z0-9_-]*')
		echo "token write - $token"
		echo "$token" > $tokenpath
		[[ $(cat $tokenpath) ]] || { echo "Не смог получить или записать токен в $tokenpath" && exit ;}
	fi
	return
}

restupload() {
	path=$1
	file=$2
	url=$(wget --header="Authorization: OAuth $token" -qO- "https://cloud-api.yandex.net/v1/disk/resources/upload?path=$path&overwrite=true")
	url=$(echo $url|cut -d',' -f2|awk -F'":"' '{print $2}'|cut -d'"' -f1)
	wget -qO/dev/null --method=PUT --body-file=$file $url
	#нужно проверять не прилетел ли 507 ответ
}

restdownload() {
	path=$1
	url=$(wget --header="Authorization: OAuth $token" -qO- "https://cloud-api.yandex.net/v1/disk/resources/download?path=$path") #тут может вылезать ошибка
	wget -q $url
}

restmkdir() {
	path=$1 #urlencode
	wget --header="Authorization: OAuth $token" -qO/dev/null --method=PUT "https://cloud-api.yandex.net/v1/disk/resources?path=$path"
}

restdel() {
	path=$1 #urlencode
	wget --header="Authorization: OAuth $token" -qO/dev/null --method=DELETE "https://cloud-api.yandex.net/v1/disk/resources?path=$path&permanently=true"
}
##REST END

#Проверка входных данных
if [ $# -eq 2 ]
then
	if echo $1|grep -E '[0-9]*' > /dev/null && echo $2|grep -E '^(day|week|month)$' > /dev/null
	then
		echo 'Проверка входных параметров пройдена.'
		if [ $useYadsk -eq "1" ]
		then
			echo 'Включено использование яндекса, проверяю наличие токена, если нету - запускаю получение нового (требует ручного подтверждения).'
			oauth $workDir"token" "$yalogin"
		fi
	else
		echo 'Некорректные входные параметры.'
		echo "$@"
		exit 1
	fi
else
	echo 'Неверное количество входных параметров. Необходимо передать количество архивов и тип плана (day\week\month)'
	exit 1
fi

func_checkfreespacespace () {
#Проверяем достаточно ли свободного места.
#Если последний созданный архив занимает больше места чем доступно сейчас - замеряем размер директории $backup и если хватает места - бекапим.
	[ $useLocalStorage -eq "1" ] && echo 'Проверка места не выполняется т.к. не включено сохранение локальных копий.' && return 0
	if [ -f $workDir'tmp/lastdu' ] && [ $(cat $workDir'tmp/lastdu'||echo 0) -gt "$freespace" ]
		then
			lastdu=`cat $workDir'tmp/lastdu'`
		
			echo "Предыдущий архив занимает ($lastdu) больше места чем доступно на диске сейчас($freespace). Замеряем размер директории файлового бекапа."
			currentdu=$(du -s --exclude='dev' --exclude='proc' --exclude='sys' --exclude='tmp' --exclude='var/spool' --exclude='run' $backup|cut -f1)
		if [ $currentdu -lt $freespace ] 
			then
				echo "Директория файлового бекапа занимает $currentdu." 
				echo "Проверка места пройдена."
				return 0
			else
				if [ $useLocalStorage -eq "1" ]
				then
					echo "Для создания локальной резервной копии недостаточно места на диске."|tee -a ./tmp/currerror
					return 1
				fi
		fi
	else
		echo "Проверка места пройдена."
		return 0
	fi
}

func_del () {
#Функция для удаления устаревших бекапов.
#Принимает в качестве параметра имя файла-списка содержащего имена удаляемых файлов.
	if [ -f $1 ]
	then
        for line in `cat $1`
                do
                deldir=`cat $line|awk -F "/" '{print $1}'`
                deleteSQL=`cat $line|awk -F ":" '{print $1}'`
		deleteSQLPG=`cat $line|awk -F ":" '{print $3}'`
                deleteRoot=`cat $line|awk -F ":" '{print $2}'`
		echo "Удаляем файлы $deleteSQL $deleteSQLPG $deleteRoot  и директорию $deldir"
				[ $useYadsk -eq "1" ] && func_yaRemove $([ $sqlnodelete -eq 0 ] && echo $deleteSQL || echo 'Последний SQL дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $sqlnodelete -eq 0 ] && echo $deleteSQLPG || echo 'Последний SQLPG дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $tarnodelete -eq 0 ] && echo $deleteRoot || echo 'Последний файловый архив был создан с ошибкой, архивы удаляться не будут.' >>$workDir'tmp/currerror') $deldir
                [ $useFtp -eq "1" ] && func_ftpRemove $([ $sqlnodelete -eq 0 ] && echo $deleteSQL || echo 'Последний SQL дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $sqlnodelete -eq 0 ] && echo $deleteSQLPG || echo 'Последний SQLPG дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $tarnodelete -eq 0 ] && echo $deleteRoot || echo 'Последний файловый архив был создан с ошибкой, архивы удаляться не будут.' >>$workDir'tmp/currerror') $deldir
				[ $useLocalStorage -eq "1" ] && func_localRemove $([ $sqlnodelete -eq 0 ] && echo $deleteSQL || echo 'Последний SQL дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $sqlnodelete -eq 0 ] && echo $deleteSQLPG || echo 'Последний SQLPG дамп был создан с ошибкой, архивы с дампами удаляться не будут.' >>$workDir'tmp/currerror') $([ $tarnodelete -eq 0 ] && echo $deleteRoot || echo 'Последний файловый архив был создан с ошибкой, архивы удаляться не будут.' >>$workDir'tmp/currerror') $deldir
		if [ $sqlnodelete -eq 0 ] || [ $tarnodelete -eq 0 ] 
		then
			rm -v -f $line
		fi
        done
		else
			return 1
		fi
}

func_localRemove() {
if [ $useLocalStorage -eq "1" ]
	then
	echo 'Удаляем локальную копию'
	for del in $@
	do
		[ -f $workDir$del ] && rm -fv $workDir$del
		[ -d $workDir$del ] && rmdir -v $workDir$del
	done
else
	echo 'Локальные копии не используется, ничего не удаляем.'
fi
}

func_ftpLoad () {
	if [ $useFtp -eq "1" ]
	then
		if [ $1 ]
		then
			load=$1
		else
			sql=$type\_$date'_sql.tar'
			sqlpg=$type\_$date'_sql.tar'
			root=$type\_$date'_root.tgz'
		fi
		echo 'Начинаем заливать на FTP.'
		/usr/bin/ftp -v -i -n $HOST <<END_SCRIPT >> $workDir'tmp/ftpload.log'
		quote USER $USER
		quote PASS $PASSWD
		$usePassiveMode
		binary
		$ftpdestdir
		mkdir $date
		cd $date
		mput $sql $sqlpg $root $load
		quit
END_SCRIPT
	grep -E '(timed out|Not connected)' $workDir'tmp/ftpload.log' >/dev/null && echo 'При загрузке возникла ошибка, возможно закончилось место или ftp сервер недоступен. Старые резервные копии не будут удалены.' && tarnodelete=1 && sqlnodelete=1
	echo 'Закончили заливать на FTP.'
else 
	echo 'FTP не используется'
fi
}
func_yaLoad () {
if [ $1 ]
		then
			load=$1
			restupload "$date/$load" "$load"
		else
			sql=$type\_$date'_sql.tar'
			sqlPG=$type\_$date'_sql_PG.tar'
			root=$type\_$date'_root.tgz'
			restupload "$date/$sql" "$sql"
			restupload "$date/$sqlPG" "$sqlPG"
			restupload "$date/$root" "$root"
		fi
}

func_yaRemove () {
echo 'Удаляем с yandex старые архивы.'
for del in $@
        do
                restdel "$del"
        done
echo 'Закончили удалять с yandex старые архивы.'
}

func_ftpRemove () {
        if [ $useFtp -eq "1" ]
        then
echo 'Удаляем с FTP старые архивы.'
                delfunc (){
                /usr/bin/ftp -v -i -n $HOST <<END_SCRIPT
                quote USER $USER
                quote PASS $PASSWD
                $usePassiveMode
                binary
		$ftpdestdir
                mdelete $1
                rmdir $1
                quit
END_SCRIPT
}
        for del in $@
        do
                delfunc "$del"
        done
echo 'Закончили удалять с FTP старые архивы.'
fi
}

days_in_month(){
  [ "$#" == "2" ] && date -d "$1/01/$2 +1month -1day" +%d
  [ "$#" == "1" ] && days_in_month $1 `date +%Y`
  [ "$#" == "0" ] && days_in_month `date +'%m %Y'`
}

days_in_count () {
i=0
currMonth=`date +%m`
sum=0
while [ $i -ne "$1" ]
do
let month=`date '+%m' -d -$'month'`
tmp=`days_in_month $month`
let sum=$sum+$tmp
let i=$i+1
done
echo $sum
}

#===================================================================================================

#Сразу меняем диру дабы ничего не сломать
cd $workDir

#Создаем директорию для временных файлов.
[ -d tmp ] || mkdir tmp
echo 'Subject:Backup script' > ./tmp/currerror
#Выполняем проверку свободного места, в случае ошибки прерываем работу скрипта.
func_checkfreespacespace || (cat ./tmp/currerror|sendmail -i $mail && exit 1)
if [ -f $workDir'tmp/lastdu' ]
then
let summ=`cat $workDir'tmp/lastdu'`*$count
let summ=$summ/1024
echo "Для текущей конфигурации необходимо $summ Мб места в хранилище (количество архивов*размер последней созданной копии)"
fi
#Во временный файл помещаем строку. Имя архива mysql и имя файлового архива.
touch ./tmp/tmp_"$2_$date"
echo  $date'/'$2_$date'_sql.tar:'$date'/'$2_$date'_root.t*:'$date'/'$2_$date'_sql_PG.tar' > ./tmp/tmp_"$2_$date"
#Отнимаем час от текущего времени и назначаем полученное в качестве времени изменения.
#Это нужно чтобы гарантировать что при след. вызове временный файлик найдется на этапе удаления устаревших архивов.
let time=$(date +%s)-1*60*60
touch -m -t $(date '+%Y%m%d%H'00 -d @${time}) ./tmp/tmp_"$2_$date"

#Создаем дириктории для нового бекапа 
backupDir=$workDir$date
[[ -d $workDir$date ]] ||mkdir $workDir$date


cd $backupDir
if [ ${mysql} -eq "1" ]
then
	echo "Бекапим mysql"
	if ! /usr/bin/mysql -u $mysqlUser --password=$mysqlPass -e 'show databases;'|awk '{print $1}' > db.list
	then
	echo 'Ошибка при подключении к БД.' |tee -a $workDir'tmp/currerror'
	sqlnodump=1
	rm db.list
	fi
	if [ $sqlnodump -eq 0 ]
	then
		sed -i '/Database/d' db.list
		sed -i '/information_schema/d' db.list
		sed -i '/performance_schema/d' db.list
		[[ -d sql ]] || mkdir sql
		cat ./db.list| while read db; do
			echo "Бекап БД $db"
			if ! /usr/bin/mysqldump -u $mysqlUser --password=$mysqlPass $db |gzip >> ./sql/$date'_'$db.sql.gz
			then
			echo "Ошибка при снятии дампа базы $db" |tee -a $workDir'tmp/currerror'
			sqlnodelete=1
			fi
		done
		echo 'Собираем БД в tar архив и удаляем временные файлы дампов'
		cd ./sql
		nice -n $ni tar -cvf ../$type\_$date'_sql.tar' ./
		cd ..
		wait $! && rm -Rfv ./sql
		rm -fv db.list
		dusql=`du -s ./$type\_$date'_sql.tar'|cut -f1`
		if [ $useFtp -eq "1" ]
		then
			echo 'Грузим архив на ftp'
			pwd
			ls
/usr/bin/ftp -v -i -n $HOST <<END_SCRIPT >> $workDir'tmp/ftpload.log'
quote USER $USER
quote PASS $PASSWD
$usePassiveMode
binary
$ftpdestdir
mkdir $date
cd $date
mput $type\_$date\_sql.tar
quit
END_SCRIPT
		fi
		if [ $useYadsk -eq "1" ]
		then
			echo 'Грузим sql архив на yandex'
			restmkdir "$date"
			sleep 1
			func_yaLoad "$type"_"$date"'_sql.tar'
		fi
	fi
fi

if [ ${pg} -eq "1" ]
then
	echo "Бекапим pgsql"
	if ! sudo -u postgres psql -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;'|awk '{print $1}'|sed '/^$/d' > dbPG.list
	then
	echo 'Ошибка при подключении к БД.' |tee -a $workDir'tmp/currerror'
	sqlnodump=1
	rm dbPG.list
	fi
	if [ $sqlnodump -eq 0 ]
	then
		[[ -d sqlpg ]] || mkdir sqlpg
		cat ./dbPG.list| while read db; do
			echo "Бекап БД $db"
			if ! pg_dump -U postgres $db |gzip > ./sqlpg/$date'_'$db.sql.gz
			then
				echo "Ошибка при снятии дампа базы $db" |tee -a $workDir'tmp/currerror'
				sqlnodelete=1
			fi
		done
		echo 'Собираем БД в tar архив и удаляем временные файлы дампов'
		cd ./sqlpg
		nice -n $ni tar -cvf ../$type\_$date'_sql_PG.tar' ./
		cd ..
		wait $! && rm -Rfv ./sqlpg
		rm -fv dbPG.list
		dupgsql=`du -s ./$type\_$date'_sql_PG.tar'|cut -f1`
		if [ $useFtp -eq "1" ]
		then
			echo 'Грузим архив на ftp'
			pwd
			ls
/usr/bin/ftp -v -i -n $HOST <<END_SCRIPT >> $workDir'tmp/ftpload.log'
quote USER $USER
quote PASS $PASSWD
$usePassiveMode
binary
$ftpdestdir
mkdir $date
cd $date
mput $type\_$date\_sql_PG.tar
quit
END_SCRIPT
		fi
		if [ $useYadsk -eq "1" ]
		then
			echo 'Грузим sql архив на yandex'
			restmkdir "$date"
			sleep 1
			func_yaLoad "$type"_"$date"'_sql_PG.tar'
		fi
	fi
fi


if [ $useYadsk -eq "1" ]
then
echo 'Делаем файловый бекап с загрузкой слайсов на yandex'
restmkdir "$date"
sleep 1
cat <<EOF >../tmp/new-volume-${type}.sh

next_volume_name=$type'_'$date'_root.tar.'\$(cat ../tmp/volno-${type})
echo "Отправляем слайс в яндекс-диск \$next_volume_name"
mv $type'_'$date'_root.tar' \$next_volume_name
url=\$(wget --header="Authorization: OAuth $token" -qO- "https://cloud-api.yandex.net/v1/disk/resources/upload?path=$date/\$next_volume_name&overwrite=true")
url=\$(echo \$url|cut -d',' -f2|awk -F'":"' '{print \$2}'|cut -d'"' -f1)
wget -qO/dev/null --method=PUT --body-file=\$next_volume_name \$url
rm -vf \$next_volume_name
EOF
chmod +x ../tmp/new-volume-${type}.sh

nice -n $ni tar -c -M --tape-length=$sliceSize --file $type\_$date'_root.tar' --new-volume-script=../tmp/new-volume-${type}.sh --volno-file=../tmp/volno-${type} --exclude='/usr/local/mgr5/tmp' --exclude='dev' --exclude='proc' --exclude='sys' --exclude='tmp' --exclude='var/spool' --exclude='var/lib/mysql' --exclude='run' --exclude='var/log' --exclude="$wd" --ignore-failed-read $backup 
tarcode="$?"
#Отправляем последний слайс (тар не зовет new-volume-script для последнего слайса)
../tmp/new-volume-${type}.sh

if [ -f ../tmp/volno-${type} ]
then
sliceCount=`cat ../tmp/volno-${type}`
#Если данных меньше чем на один слайс 
[ $sliceCount -eq "1" ] && func_yaLoad "$type"_"$date"'_root.tar'
fi
rm -f ../tmp/volno-${type} ../tmp/new-volume-${type}.sh
fi

if [ $useFtp -eq "1" ]
then
echo 'Делаем файловый бекап с загрузкой слайсов на ftp'
cat <<EOF >../tmp/new-volume-${type}.sh
next_volume_name=$type'_'$date'_root.tar.'\$(cat ../tmp/volno-${type})
echo "Отправляем слайс в ftp \$next_volume_name"
mv $type'_'$date'_root.tar' \$next_volume_name
/usr/bin/ftp -v -i -n $HOST <<END_SCRIPT >> ../tmp/ftpload.log
quote USER $USER
quote PASS $PASSWD
$usePassiveMode
binary
$ftpdestdir
mkdir $date
cd $date
mput \$next_volume_name
quit
END_SCRIPT
rm -vf \$next_volume_name
EOF
chmod +x ../tmp/new-volume-${type}.sh

nice -n $ni tar -c -M --tape-length=$sliceSize --file $type\_$date'_root.tar' --new-volume-script=../tmp/new-volume-${type}.sh --volno-file=../tmp/volno-${type} --exclude='/usr/local/mgr5/tmp' --exclude='dev' --exclude='proc' --exclude='sys' --exclude='tmp' --exclude='var/spool' --exclude='var/lib/mysql' --exclude='run' --exclude='var/log' --exclude="$wd" --ignore-failed-read $backup 
tarcode="$?"
#Отправляем последний слайс (тар не зовет new-volume-script для последнего слайса)
../tmp/new-volume-${type}.sh

if [ -f ../tmp/volno-${type} ]
then
sliceCount=`cat ../tmp/volno-${type}`
#Если данных меньше чем на один слайс 
[ $sliceCount -eq "1" ] && func_ftpLoad $type\_$date'_root.tar'
fi
rm -f ../tmp/volno-${type} ../tmp/new-volume-${type}.sh
fi

if [ $useLocalStorage -eq "1" ]
then
	echo 'Делаем локальный файловый бекап.'
	nice -n $ni tar -zcf $2_$date'_root.tgz' --exclude='/usr/local/mgr5/tmp' --exclude='dev' --exclude='proc' --exclude='sys' --exclude='tmp' --exclude='var/spool' --exclude='var/lib/mysql' --exclude='run' --exclude='var/log' --exclude="$wd" --ignore-failed-read $backup
tarcode="$?"
fi

if [ $tarcode -gt 1 ]
then
	echo 'Ошибка при создании файлового дампа.'|tee $workDir'tmp/currerror' 
	tarnodelete=1
fi


[ $tarnodelete -eq 0 ] && duroot=`([ $useFtp -eq "1" ]||[ $useYadsk -eq "1" ]) && { let size=${sliceCount}*${sliceSize} && echo ${size} ;} || du -s $2_$date'_root.tgz'|cut -f1`

[ $dusql ] || dusql=0
[ $dupgsql ] || dupgsql=0

if [ $duroot ]
then	
	let dusum=$duroot+$dusql+$dupgsql
else
	dusum=$duroot
fi
echo "Общий размер архива: $dusum"
[ ${dusum} -gt 0 ] && echo $dusum > ../tmp/lastdu

cd ${workDir}

if [ $useLocalStorage -eq "0" ]
	then
	echo "PID Текущего скрипта: $$"
	if ps ax|grep "$BASH_SOURCE"|grep -Ev "^([[:space:]]|)$$|grep|$ppid"
	then
		echo 'Выполняется другая копия данного скрипта, удаление свеже-созданной копии будет выполнено последним запущенным экземпляром скрипта.'
	else
		echo 'Удаляем свеже-созданную копию с локального диска'
		rm -rvf $backupDir
	fi
else
	echo 'Используются локальные копии'
fi

cd ${workDir}/tmp

#Находим и читаем старые временные файлы. Удаляем старые архивы и временные файлы.
if [[ $type = 'day' ]]
then
echo "Ищем устаревшие бекпапы, тип бекапов $type "
find $workDir'tmp' -type f -name "tmp_$type\_*" -mtime +$count2 > DelList
echo "Найдены след. временные файлы:" && cat DelList && echo "Передаем список функции удаления"
func_del DelList
rm -f DelList
fi

if [[ $type = 'week' ]]
then
echo "Ищем устаревшие бекпапы, тип бекапов $type "
let count2=$count2*7
find $workDir'tmp' -type f -name "tmp_$type\_*" -mtime +$count2 > DelList
echo "Найдены след. временные файлы:" && cat DelList && echo "Передаем список функции удаления"
func_del DelList
rm -f DelList
fi

if [[ $type = 'month' ]]
then
echo "Ищем устаревшие бекпапы, тип бекапов $type "
result=`days_in_count $count2`
find $workDir'tmp' -type f -name "tmp_$type\_*" -mtime +$result > DelList
echo "Найдены след. временные файлы:" && cat DelList && echo "Передаем список функции удаления"
func_del DelList
rm -f DelList
fi

if [[ $type = 'year' ]]
then
echo "Ищем устаревшие бекпапы, тип бекапов $type "
let count2=$count2*12
result=`days_in_count $count2`
find $workDir'tmp' -type f -name "tmp_$type\_*" -mtime +$result > DelList
echo "Найдены след. временные файлы:" && cat DelList && echo "Передаем список функции удаления"
func_del DelList
rm -f DelList
fi


if [ `wc -l $workDir'tmp/currerror'|cut -d' ' -f1` -gt 1 ]
then
cat $workDir'tmp/currerror'|sendmail -i $mail
rm -f $workDir'tmp/currerror'
else
rm -f $workDir'tmp/currerror'
fi

exit
