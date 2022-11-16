#!/bin/bash
###
# @Author: zhangzhihua 54562841@qq.com
# @Date: 2020-01-21 11:25:26
# @LastEditors: zhangzhihua
# @LastEditTime: 2022-10-20 11:02:18
###
#--------------------------------------------
# 使用介绍 ： flutter开发项目中，兼容iOS Android自动打包上传到蒲公英脚本 2022.3.1
# 使用方式 ： sh dabao.sh /user/xxx/shop_app 1 3 1
# 使用说明列举如下 ：
# 1.包含自动打iOS Android包，android必须为flutter项目
# 2.自动上传到蒲公英平台，可自定义apikey ukey，以及上传后自动打开下载的web界面
# 3.上传完毕，自动清理打包的产生的ipa apk等垃圾文件
# 4.$1为需要打包的项目地址
# 5.$2为可传对应平台 1:iOS  2:Android
# 6.$3为对应环境 1:正式 2:灰度 3:测试 4:开发 5:App Store(iOS)
# 此shell依赖 ipa.sh 和 upload.sh
#--------------------------------------------

log() {
  echo "\033[42;97m $* \033[0m"
}

exitShell() {
  # killall iTerm2  #这两个会把所有的都关掉,不可以
  exit 0 #退出了后边就无法执行了
  # killall Terminal #为了用于command时,关闭窗口
  # osascript -e "tell application \"System Events\" to keystroke \"w\" using command down"
}

removeTrash() {
  buildPath1=${project_path}/build/ #使用flutter命令打的安卓包
  buildPath2=${project_path}/android/app/build/
  buildPath3=${project_path}/ios/Package/          #使用xcodebuild命令打的ios包
  buildPath4=${project_path}/ios/fastlane/Package/ #使用fastlane打的ios包
  rm -rf ${buildPath1}
  rm -rf ${buildPath2}
  rm -rf ${buildPath3}
  rm -rf ${buildPath4}

  nowTime=$(date +%Y-%m-%d-%H:%M:%S)
  nowTime_s=$(date +%s)
  # log "现在时间: "$nowTime_s
  cd $PARENT_DIR
  if [ ! -e lastBuildTime ]; then
    touch lastBuildTime
    echo $nowTime_s >lastBuildTime
    # log "写入历史值: "$nowTime_s
  fi
  oldValue_s=$(sed -n '1p' lastBuildTime)
  pass=$((nowTime_s - oldValue_s))
  # log "间隔差值: "$pass
  if [[ $pass -gt 86400 ]]; then #86400是24个小时
    echo $nowTime_s >lastBuildTime
    sh clear.sh
  fi
  log '清理完成'
  exitShell
}

showArchiveTime() {
  endTime=$(date +%Y-%m-%d-%H:%M:%S)
  endTime_s=$(date +%s)
  sumTime=$(($endTime_s - $startTime_s))
  log "打包开始时间 $startTime"
  log "上传结束时间 $endTime"
  endDes='打包上传用时:'
  if (($sumTime > 60)); then
    hour=$(expr ${sumTime} / 60)
    used=$(expr ${hour} \* 60)
    left=$(expr ${sumTime} - ${used})
    log "${endDes} ${hour}分${left}秒"
  else
    log "${endDes} ${sumTime}秒"
  fi
}

completeArchive() {
  if [[ $agconnect_services ]]; then
    git checkout -- $agconnect_services #安卓打包重置华为配置文件
  fi
  showArchiveTime
  removeTrash
}

uploadArchive() {
  if [[ -e $packagePath ]]; then
    cd $CURRENT_DIR
    sh upload.sh ${packagePath}
    completeArchive
  else
    log '打包失败,ipa/apk包找不到'
    exitShell
  fi
}

packageiOS() {
  log "开始打iOS-${target}环境"
  cd $CURRENT_DIR
  if [ ${env} == 5 ]; then #如果testflight,暂时不需要打ipa包,手动上传
    sh ipa.sh $project_path $target 1
    # 自己去上传
    cd $project_path
    packagePath=$(find ${project_path}/ios/Package/${target} -name "*.ipa")
    open $packagePath
  else
    sh ipa.sh $project_path/ios $target
    if [ $? -ne 0 ]; then
      log '打包ipa失败了'
    else
      cd $project_path
      packagePath=$(find ${project_path}/ios/Package/${target} -name "*.ipa")
      uploadArchive
    fi
  fi
}

handleHuaweiConfig() {
  packageJson=$(find ${project_path}/android/app -name "agconnect-services-${target}.json")
  agconnect_services=$(find ${project_path}/android/app -name "agconnect-services.json")

  if [[ -e $packageJson && -e $agconnect_services ]]; then
    log $packageJson
    log $agconnect_services
    cp $packageJson $agconnect_services
    log '存在要打包的json,已处理'
  fi
}

packageAndroid() {
  log "开始打Android-${target}环境"
  cd $project_path
  handleHuaweiConfig
  flutter build apk --flavor ${target} --release
  packagePath=$(find ${project_path}/build/app/outputs/flutter-apk -name "app-${target}-release.apk")
  uploadArchive
}

updatePub() {
  ulimit -n 4096
  flutter clean
  flutter packages pub get
  if [ $? -ne 0 ]; then
    log 'flutter pub get失败了'
  else
    log 'pub get完成'
  fi
  flutter packages upgrade
  if [ $? -ne 0 ]; then
    log 'flutter packages upgrade失败了'
  else
    log 'pub upgrade完成'
  fi
}

askArchive() {
  cd $project_path
  branch=$(git branch --show-current)
  log "当前的代码分支为: $branch"
  git stash
  git pull
  git stash pop
  # git add . #这里不能添加这个,此处只是拉代码
  # flutter pub cache repair
  updatePub
}

prePackage() {
  startTime=$(date +%Y-%m-%d-%H:%M:%S)
  startTime_s=$(date +%s)
  if (($isFast == 1)); then
    log '开启快速打包'
  else
    log '默认全面打包'
    askArchive
  fi

  if ((${plat} == 1)); then
    packageiOS
  elif ((${plat} == 2)); then
    packageAndroid
  else
    log "没有找到打包的平台,自动退出打包"
    exitShell
  fi
}

handlePlat() {
  if ((${plat} == 1)); then
    log "选择的平台是iOS"
  elif ((${plat} == 2)); then
    log "选择的平台是Android"
  else
    log "没有找到打包的平台,自动退出打包"
    exitShell
  fi
}

handleVersion() {
  ss='选择的flutter版本是'
  if ((${version} == 1)); then
    log $ss'3.0.5'
    export PATH=/Users/ke/Documents/flutter_3.0.5/bin:$PATH
  elif ((${version} == 2)); then
    log $ss'2.10.5'
    export PATH=/Users/ke/Documents/flutter_2.10.5/bin:$PATH
  elif ((${version} == 3)); then
    log $ss'2.8.1'
    export PATH=/Users/ke/Documents/flutter_2.8.1/bin:$PATH
  elif ((${version} == 4)); then
    log $ss'2.5.3'
    export PATH=/Users/ke/Documents/flutter_2.5.3/bin:$PATH
  elif ((${version} == 5)); then
    export PATH=/Users/ke/Documents/flutter/bin:$PATH
  else
    log "没有找到打包的flutter版本,自动退出打包"
    exitShell
  fi
}

handleEnv() {
  ss='选择的环境是'
  if ((${env} == 1)); then
    log $ss'正式'
    if ((${plat} == 1)); then
      target=Runner
    elif ((${plat} == 2)); then
      target=tencent
    else
      target=''
    fi
  elif ((${env} == 2)); then
    log $ss'灰度'
    target=pre
  elif ((${env} == 3)); then
    log $ss'测试'
    target=beta
  elif ((${env} == 4)); then
    log $ss'开发'
    target=dev
  elif ((${env} == 5)); then
    if ((${plat} == 1)); then
      target=Runner
    else
      log "没有找到选择的环境,退出自动化打包"
      exitShell
    fi
  else
    log "没有找到选择的环境,退出自动化打包"
    exitShell
  fi
}

project_path=$1

CURRENT_DIR=$(
  cd $(dirname $0)
  pwd
)
PARENT_DIR=$(
  cd $(dirname $0)
  cd ..
  pwd
)

if [[ -e $project_path ]]; then
  if [[ -e "$project_path/ios" && -e "$project_path/android" ]]; then
    if [[ -e "$project_path/example" ]]; then
      log '是flutter plugin项目'
      project_path=$project_path/example
    else
      log '是flutter application项目'
    fi
  else
    log '项目路径不存在，退出自动化打包'
    exitShell
  fi

  if [[ -n $2 && -n $3 && -n $4 && -n $5 ]]; then
    plat=$2
    env=$3
    version=$4
    handlePlat
    handleEnv
    handleVersion
    isFast=$5
  else
    log "请输入要打包的平台，1:iOS  2:Android"
    read -n1 plat
    log
    handlePlat
    log "请输入要打包的环境，1:正式  2:灰度  3:测试  4:开发  5:App Store"
    read -n1 env
    log
    handleEnv
    log "请输入要打包的flutter环境版本，1:3.0.5  2:2.10.5  3:2.8.1  4:2.5.3  5.最新版本"
    read -n1 version
    log
    handleVersion
    log "请输入是否需要打包速度模式，1:快速打包(必须保证可以运行的)  2:传统打包(会处理代码和三方库)"
    read -n1 isFast
    log
  fi
  prePackage
else
  log '项目路径不存在，退出自动化打包'
  exitShell
fi
