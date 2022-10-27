#!/bin/bash
### 专注上传ipa apk 30年!!!
# @Author: zhangzhihua 54562841@qq.com
# @Date: 2022-08-21 11:17:14
# @LastEditors: zhangzhihua
# @LastEditTime: 2022-08-26 23:51:30
#
# 通过shell脚本来实现将本地app文件通过API上传到蒲公英
# https://www.pgyer.com/doc/view/api#fastUploadApp
##
# 参数说明：
# $1: 要上传的文件路径(ipa/apk)
#

# hopson
readonly api_key="caa6bdf185bef46bbe828fae81a15506"

# zhang
# readonly api_key='c5b7baed38a6c2fa99d972caa9a2a0a7'
readonly file=$1

printHelp() {
  echo "Usage: $0 api_key file"
  echo "Example: $0 <your_api_key> <your_apk_or_ipa_path>"
}

# check api_key exists
if [ -z "$api_key" ]; then
  echo "api_key is empty"
  printHelp
  exit 1
fi

# check file exists
if [ ! -f "$file" ]; then
  echo "file not exists"
  printHelp
  exit 1
fi

if [[ $file =~ ipa$ ]]; then
  app_type="ios"
elif [[ $file =~ apk$ ]]; then
  app_type="android"
else
  echo "file type not support"
  printHelp
  exit 1
fi

# ---------------------------------------------------------------
# functions
# ---------------------------------------------------------------

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

logTitle() {
  log "-------------------------------- $* --------------------------------"
}

execCommand() {
  log "$@"
  result=$(eval $@)
}

showUploadTime() {
  endTime=$(date +%Y-%m-%d-%H:%M:%S)
  endTime_s=$(date +%s)
  sumTime=$(($endTime_s - $startTime_s))
  # echo "\033[33;1m上传开始时间 $startTime\033[0m"
  # echo "\033[33;1m上传结束时间 $endTime\033[0m"
  if (($sumTime > 60)); then
    hour=$(expr ${sumTime} / 60)
    used=$(expr ${hour} \* 60)
    left=$(expr ${sumTime} - ${used})
    echo "\033[33;1m上传用时 ${hour}分${left}秒\033[0m"
  else
    echo "\033[33;1m上传用时 ${sumTime}秒\033[0m"
  fi
}

# ---------------------------------------------------------------
# 获取上传凭证
# ---------------------------------------------------------------
startTime=$(date +%Y-%m-%d-%H:%M:%S)
startTime_s=$(date +%s)

logTitle "获取凭证"

execCommand "curl -s -F '_api_key=${api_key}' -F 'buildType=${app_type}' http://www.pgyer.com/apiv2/app/getCOSToken"
echo ${result} | jq
[[ "${result}" =~ \"endpoint\":\"([\:\_\.\/\\A-Za-z0-9\-]+)\" ]] && endpoint=$(echo ${BASH_REMATCH[1]} | sed 's!\\\/!/!g')
[[ "${result}" =~ \"key\":\"([\.a-z0-9]+)\" ]] && key=$(echo ${BASH_REMATCH[1]})
[[ "${result}" =~ \"signature\":\"([\=\&\_\;A-Za-z0-9\-]+)\" ]] && signature=$(echo ${BASH_REMATCH[1]})
[[ "${result}" =~ \"x-cos-security-token\":\"([\_A-Za-z0-9\-]+)\" ]] && x_cos_security_token=$(echo ${BASH_REMATCH[1]})

if [ -z "$key" ] || [ -z "$signature" ] || [ -z "$x_cos_security_token" ] || [ -z "$endpoint" ]; then
  log "get upload token failed"
  exit 1
fi

# ---------------------------------------------------------------
# 上传文件
# ---------------------------------------------------------------

logTitle "上传文件"

execCommand "curl -s -o /dev/null -w '%{http_code}' --form-string 'key=${key}' --form-string 'signature=${signature}' --form-string 'x-cos-security-token=${x_cos_security_token}' -F 'file=@${file}' ${endpoint}"
echo ${result} | jq
if [ $result -ne 204 ]; then
  log "Upload failed"
  exit 1
fi

# ---------------------------------------------------------------
# 检查结果
# ---------------------------------------------------------------

logTitle "检查结果"

for i in {1..60}; do
  execCommand "curl -s http://www.pgyer.com/apiv2/app/buildInfo?_api_key=${api_key}\&buildKey=${key}"
  [[ "${result}" =~ \"code\":([0-9]+) ]] && code=$(echo ${BASH_REMATCH[1]})
  if [ $code -eq 0 ]; then
    echo ${result} | jq
    showUploadTime
    [[ "${result}" =~ \"buildQRCodeURL\":\"([\:\_\.\/\\A-Za-z0-9\-]+)\" ]] && buildQRCodeURL=$(echo ${BASH_REMATCH[1]} | sed 's!\\\/!/!g')
    open $buildQRCodeURL

    [[ "${result}" =~ \"buildShortcutUrl\":\"([\:\_\.\/\\A-Za-z0-9\-]+)\" ]] && buildShortcutUrl=$(echo ${BASH_REMATCH[1]} | sed 's!\\\/!/!g')
    open 'https://www.pgyer.com/'$buildShortcutUrl
    break
  else
    sleep 1
  fi
done
