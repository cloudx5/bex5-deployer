#!/bin/bash

if [ -z "$X5_VERSION" ]; then
        echo >&2 '请设置$X5_VERSION 环境变量，该变量标识使用的BeX5版本，例如3.5 '
        exit 1
fi

if [ -z "$WEBAPPS_URL" ]; then
	echo >&2 '请设置$WEBAPPS_URL环境变量 '
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

# conf, license
cd $JUSTEP_HOME
rm -rf *

echo "正在更新 conf..."
curl $BEX5_URL/conf.tar.gz -o conf.tar.gz
tar -xf conf.tar.gz
echo "conf 更新完毕"

echo "正在更新 license..."
curl $BEX5_URL/license.tar.gz -o license.tar.gz
tar -xf license.tar.gz
echo "license 更新完毕"

# webapps
cd $WEBAPPS_DIR
rm -rf ROOT*
rm -rf x5*
rm -rf BusinessServer*
rm -rf ReportServer*
rm -rf DocServer*
rm -rf baas*

echo "正在更新 ROOT.war..."
curl $BEX5_URL/ROOT.war -o $WEBAPPS_DIR/ROOT.war
echo "ROOT.war 更新完毕"

echo "正在更新 x5.war..."
curl $BEX5_URL/x5.war -o $WEBAPPS_DIR/x5.war
echo "x5.war 更新完毕"

echo "正在更新 BusinessServer.war..."
curl $BEX5_URL/BusinessServer.war -o $WEBAPPS_DIR/BusinessServer.war
echo "BusinessServer.war 更新完毕"

echo "正在更新 ReportServer.war..."
curl $BEX5_URL/ReportServer.war -o $WEBAPPS_DIR/ReportServer.war
echo "ReportServer.war 更新完毕"

echo "正在更新 DocServer.war..."
curl $BEX5_URL/DocServer.war -o $WEBAPPS_DIR/DocServer.war
echo "DocServer.war 更新完毕"

echo "正在更新 baas.war..."
curl $BEX5_URL/baas.war -o $WEBAPPS_DIR/baas.war
echo "baas.war 更新完毕"

# model, doc, sql
cd $JUSTEP_HOME

echo "正在下载 model.tar.gz..."
curl $DIST_URL/model.tar.gz -o $JUSTEP_HOME/model.tar.gz
echo "model.tar.gz 下载完毕"

echo "正在下载 doc.tar.gz..."
curl $DIST_URL/doc.tar.gz -f -o $JUSTEP_HOME/doc.tar.gz
echo "doc.tar.gz 下载完毕"

echo "正在下载 sql.tar.gz..."
curl $DIST_URL/sql.tar.gz -f -o $JUSTEP_HOME/sql.tar.gz
echo "sql.tar.gz 下载完毕"

echo "正在更新 model..."
tar -xf model.tar.gz -C ./
echo "model 更新完毕"
echo ""

echo "正在更新 doc..."
mkdir data
tar -xf doc.tar.gz -C ./data
echo "doc 更新完毕"
echo ""

echo "正在更新 sql..."
mkdir sql
tar -xf sql.tar.gz -C ./ 
echo "sql 更新完毕"
echo ""

# init database
SQL_PATH="$JUSTEP_HOME/sql"
LOG_PATH="$SQL_PATH/sqlload_`date +%Y%m%d%H%M%S`.log"
load_script(){
  TMP="tmp_script"
  echo "" >$TMP
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

  cat $TMP

  START_TIME=$(date "+%s")
  ./mysql --default-character-set=utf8 -hdatabase -uroot -px5 -ve "source $TMP" >$LOG_PATH 2>&1
  if [ $? -eq 0 ];then
    echo "[$?]脚本导入成功！共计用时: " `expr $(date "+%s") - ${START_TIME}` " 秒"
  else
    echo "[$?]脚本导入失败，正在结束..."
    exit 1
  fi
}

file_list=`ls -A $SQL_PATH`
if [ "$file_list" ];then
  cd $SQL_PATH
  echo "获取mysql客户端..."
  curl $PRODUCT_URL/mysql/5.6/mysql -o mysql
  chmod a+x mysql
  echo "开始初始化 SQL 脚本..."
  load_script $SQL_PATH
fi

