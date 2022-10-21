#!/bin/bash
#Extract script.
#Нужно малость переделать для возможности распаковки архива не с первого тома (для случаев когде не все архивы есть).

if [ $1 ] && [ -f $1 ]
then
         tar -M -xf $1 --volno-file=/tmp/volno -F "$BASH_SOURCE tar" -C ./
fi

if [ $1 ] && [ $1 == "tar" ]
then
        name=$(echo $TAR_ARCHIVE|sed 's/\.[0-9]*$//')
        if [ -f $name.$TAR_VOLUME ]
        then
		echo $name.$TAR_VOLUME
                echo $name.$TAR_VOLUME >&$TAR_FD
                else
		echo "extracted $(cat /tmp/volno) archives."
                rm -f /tmp/volno
                exit 1
        fi
fi
