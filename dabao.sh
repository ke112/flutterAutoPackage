#!/bin/bash
#--------------------------------------------
# 介绍 ： flutter开发项目中，兼容iOS Android自动打包上传到蒲公英脚本 2022.3.1
# 1.包含自动打iOS Android包，android必须为flutter项目
# 2.自动上传到蒲公英平台，可自定义apikey ukey，以及上传后自动打开下载的web界面
# 3.上传完毕，自动清理打包的产生的ipa apk等垃圾文件

# 使用命令：
# cd && sh /Users/ke/Desktop/my_git/flutterAutoPackage/dabao.sh /Users/ke/Desktop/合生通app/mlife_app_b 1 3 5 2
# 4.$1为需要打包的项目地址
# 5.$2为可传对应平台 1:iOS  2:Android
# 6.$3为对应环境 1:正式  2:灰度  3:测试  4:开发  5:App Store(iOS)
# 7.$4为flutter开发环境 1.最新版本  2:3.0.5  3:2.10.5  4:2.8.1  5:2.5.3
# 6.$5为打包模式 1:常规打包  2:快速打包 (tip:区别在于常规打包包括拉取新代码以及flutter三方库的更新,快速打包模式务必保证是可以直接运行的代码)

# 注意:
# 1.针对打安卓包,如果一直running grade task卡住,需要替换flutter sdk以及当前Android/app 中的repositories
# 2.为实现解耦功能,部分功能拆解开,此shell依赖 ipa.sh 和 upload.sh
#--------------------------------------------

CURRENT_DIR=$(
  cd $(dirname $0)
  pwd
)

function log() {
  echo "\033[42;97m $* \033[0m"
}

function exitShell() {
  # killall iTerm2  #这两个会把所有的都关掉,不可以
  # exit 0 #退出了后边就无法执行了
  # killall Terminal #为了用于command时,关闭窗口
  # osascript -e "tell application \"System Events\" to keystroke \"w\" using command down"
  echo '退出'
}

function removeTrash() {
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
  cd $CURRENT_DIR

  if [ ! -e lastBuildTime ]; then
    touch lastBuildTime
    echo $nowTime >>lastBuildTime
    echo $nowTime_s >>lastBuildTime
    echo "" >>lastBuildTime
    log "写入历史值: "$nowTime_s
  fi
  # oldValue_s=$(sed -n '1p' lastBuildTime)
  # pass=$((nowTime_s - oldValue_s))
  # log "间隔差值: "$pass
  if [[ $pass -gt $((86400 * 7)) ]]; then #86400是24个小时
    # rm lastBuildTime
    echo $nowTime >>lastBuildTime
    echo $nowTime_s >>lastBuildTime
    echo "" >>lastBuildTime
    echo '周期性清理了..'
  fi
  exitShell
}

function showArchiveTime() {
  endTime=$(date +%Y-%m-%d-%H:%M:%S)
  endTime_s=$(date +%s)
  sumTime=$(($endTime_s - $startTime_s))
  log "打包开始: $startTime"
  log "上传结束: $endTime"
  endDes='上传用时:'
  if (($sumTime > 60)); then
    hour=$(expr ${sumTime} / 60)
    used=$(expr ${hour} \* 60)
    left=$(expr ${sumTime} - ${used})
    log "${endDes} ${hour}分${left}秒"
  else
    log "${endDes} ${sumTime}秒"
  fi
}

function discardAndroidDynamicConfig() {
  if [[ -e $agconnect_services ]]; then
    cd $project_path
    git checkout -- $agconnect_services #安卓打包重置华为配置文件
    log 'Android华为推送json文件已重置'
  fi
}

function uploadArchive() {
  if [[ -e $packagePath ]]; then
    cd $CURRENT_DIR
    sh upload.sh ${packagePath}
    if [ $? -ne 0 ]; then
      uploadArchive
    else #上传完成
      discardAndroidDynamicConfig
      showArchiveTime
      removeTrash
    fi
  else
    log 'ipa/apk包找不到'
    exitShell
  fi
}

function packageiOS() {
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
    cd $project_path
    packagePath=$(find ${project_path}/ios/Package/${target} -name "*.ipa")
    if [[ -e $packagePath ]]; then
      uploadArchive
    else
      log '打包ipa失败了'
      packageiOS
    fi
  fi
}

function androidDynamicConfig() {
  packageJson=$(find ${project_path}/android/app -name "agconnect-services-${target}.json")
  agconnect_services=$(find ${project_path}/android/app -name "agconnect-services.json")

  if [[ -e $packageJson && -e $agconnect_services ]]; then
    log $packageJson
    log $agconnect_services
    cp $packageJson $agconnect_services
    log '存在要打包的华为推送json,已处理'
  fi
}

function packageAndroid() {
  log "开始打Android-${target}环境"
  cd $project_path
  androidDynamicConfig
  flutter build apk --flavor ${target} --release
  packagePath=$(find ${project_path}/build/app/outputs/flutter-apk -name "app-${target}-release.apk")
  if [[ -e $packagePath ]]; then
    uploadArchive
  else
    log '打包apk失败了'
    packageAndroid
  fi
}

function updatePub() {
  ulimit -n 4096
  flutter clean
  flutter packages pub get
  if [ $? -ne 0 ]; then
    log 'flutter pub get失败了'
    updatePub
  else
    log 'pub get完成'
  fi
  # flutter packages upgrade
  # if [ $? -ne 0 ]; then
  #   log 'flutter packages upgrade失败了'
  # else
  #   log 'pub upgrade完成'
  # fi
}

function askArchive() {
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

function prePackage() {
  startTime=$(date +%Y-%m-%d-%H:%M:%S)
  startTime_s=$(date +%s)
  if (($isFast == 2)); then
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

function handlePlat() {
  if ((${plat} == 1)); then
    log "选择的平台是iOS"
  elif ((${plat} == 2)); then
    log "选择的平台是Android"
  else
    log "没有找到打包的平台,自动退出打包"
    exitShell
  fi
}

function handleVersion() {
  ss='选择的flutter版本是'
  if ((${version} == 1)); then
    log $ss'最新的'
    export PATH=/Users/ke/Documents/flutter/bin:$PATH
  elif ((${version} == 2)); then
    log $ss'3.0.5'
    export PATH=/Users/ke/Documents/flutter_3.0.5/bin:$PATH
  elif ((${version} == 3)); then
    log $ss'2.10.5'
    export PATH=/Users/ke/Documents/flutter_2.10.5/bin:$PATH
  elif ((${version} == 4)); then
    log $ss'2.8.1'
    export PATH=/Users/ke/Documents/flutter_2.8.1/bin:$PATH
  elif ((${version} == 5)); then
    log $ss'2.5.3'
    export PATH=/Users/ke/Documents/flutter_2.5.3/bin:$PATH
  else
    log "没有找到打包的flutter版本,自动退出打包"
    exitShell
  fi
  # flutter --version
}

function handleEnv() {
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
    log "请输入要打包的flutter环境版本，1.最新版本 2:3.0.5  3:2.10.5  4:2.8.1  5:2.5.3"
    read -n1 version
    log
    handleVersion
    log "请输入是否需要打包速度模式，1:传统打包(会处理代码和三方库)  2:快速打包(必须保证可以运行的)"
    read -n1 isFast
    log
  fi
  prePackage
else
  log '项目路径不存在，退出自动化打包'
  exitShell
fi
