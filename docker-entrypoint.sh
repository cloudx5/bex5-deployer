#!/bin/bash

if [ -z "$X5_VERSION" ]; then
  echo >&2 '请设置$X5_VERSION 环境变量，该变量标识使用的BeX5版本，例如3.5 '
  exit 1
fi

if [ -z "$DIST_URL" ]; then
  echo >&2 '请设置$DIST_URL环境变量 '
  exit 1
fi

PRODUCT_URL=http://jenkins.console:8080/dist/product
BEX5_URL=$PRODUCT_URL/bex5/$X5_VERSION
WEBAPPS_DIR=/usr/local/tomcat/webapps
JUSTEP_HOME=/usr/local/x5

# 暂停5秒，等待网络准备完成
sleep 5

# 清空weapps下应用，需部署的应用最后在放置
cd $WEBAPPS_DIR
rm -rf *

# conf, license, model, doc, sql

download_tar(){
  # $1: url $2: filename
  rm -rf $2.tar.gz
  echo "  正在更新 $2..."
  curl -s -f $1/$2.tar.gz -o $2.tar.gz
  ERROR=$?
  if [ "$ERROR" -eq "0" ]; then
    tar -xf $2.tar.gz -C ./
    echo "  $2 更新完毕"
  else
    echo "  [$ERROR]更新 $2 失败"
    exit 1
  fi
}

cd $JUSTEP_HOME
rm -rf *

echo "当前使用的BeX5版本：$X5_VERSION"
echo "正在更新BeX5基础配置文件..."
download_tar $BEX5_URL/home conf
download_tar $BEX5_URL/home license
echo "更新BeX5基础配置文件完毕"

echo "正在更新资源..."
download_tar $DIST_URL/home model
download_tar $DIST_URL/home sql
mkdir -p data && cd data
download_tar $DIST_URL/home doc 
echo "更新资源完毕"

# init database
if [ "$INIT_DB"x = "false"x ]; then
  echo "$INIT_DB=false，忽略数据库初始化"
else
  SQL_PATH="$JUSTEP_HOME/sql"
  LOG_PATH="$SQL_PATH/sqlload_`date +%Y%m%d%H%M%S`.log"
  load_script(){
    TMP="tmp_script"
    echo "DROP DATABASE IF EXISTS x5;" >>$TMP
    echo "CREATE DATABASE x5;" >>$TMP
    echo "USE x5;" >>$TMP
    echo "SET FOREIGN_KEY_CHECKS=0;" >>$TMP
    echo "SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';" >>$TMP
    for FILE_NAME in `ls -A $1/*.sql`;do
      echo "source $FILE_NAME;" >>$TMP
    done
    echo "SET FOREIGN_KEY_CHECKS=1;" >>$TMP
    echo "SET SQL_MODE='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';" >>$TMP
    echo "commit;" >>$TMP
    echo "quit" >>$TMP
    echo "" >>$TMP

    START_TIME=$(date "+%s")
    ./mysql --default-character-set=utf8 -hdatabase -uroot -px5 -ve "source $TMP" >$LOG_PATH 2>&1
    ERROR=$?
    if [ "$ERROR" -eq "0" ]; then
      echo "数据库初始化成功！共计用时: " `expr $(date "+%s") - ${START_TIME}` " 秒"
    else
      echo "[$ERROR]数据库初始化失败"
      exit 1
    fi
  }

  file_list=`ls -A $SQL_PATH`
  if [ "$file_list" ]; then
    cd $SQL_PATH
    echo "获取mysql客户端..."
    curl -s -f $PRODUCT_URL/mysql/5.6/mysql -o mysql
    chmod a+x mysql
    echo "开始数据库初始化..."
    load_script $SQL_PATH
  fi
fi

# webapps最后在更新，避免相关资源未准备而访问错误

download_webapps(){
  rm -rf $WEBAPPS_DIR/webapps.txt
  curl -s -f $1/webapps.txt -o $WEBAPPS_DIR/webapps.txt
  if [ "$?" -eq "0" ]; then
    while read webapp
    do
      echo "  正在更新 $webapp..."
      curl -s -f $1/$webapp -o $WEBAPPS_DIR/$webapp
      ERROR=$?
      if [ "$ERROR" -eq "0" ]; then
        echo "  $webapp 更新完毕"
      else
        echo "  [$ERROR]更新 $webapp 失败"
        exit 1
      fi
    done < $WEBAPPS_DIR/webapps.txt
  fi
}

cd $WEBAPPS_DIR

echo "正在更新BeX5运行时..."
download_webapps $BEX5_URL/webapps
echo "更新BeX5运行时完毕"

if [ -n "$INDEX_URL" ]; then
  echo "设置入口地址INDEX_URL为：$INDEX_URL"
  INDEX_FILE="$WEBAPPS_DIR/ROOT/index.html"
  mkdir -p $WEBAPPS_DIR/ROOT
  echo "<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">" > $INDEX_FILE
  echo "<html><head><script type="text/javascript">window.location=\"$INDEX_URL\";</script></head></html>" >> $INDEX_FILE
fi

echo "正在更新自定义webapps..."
download_webapps $DIST_URL/webapps
echo "自定义webapps更新完毕"

