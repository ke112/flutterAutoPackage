#!/bin/bash
###
# 使用方法:
# step1: 打开终端，进入到本脚本所在的目录下,然后执行以下命令. 项木路径可以是flutter根路径,也可以是ios根路径.
# step2: 输入 sh archive.sh /User/ke/DeskTop/hopson_shop/ios dev 1
#
# 参数说明：
# $1: 要打包的项目路径
# $2: 要打包的项目环境,通过--flavor关联
# $3: 针对iOS平台,是否通过testflight导出发布
#

# 参数配置
project_dir=$1
scheme=$2
testflight=$3

log() {
  echo "\033[42;97m $* \033[0m"
}

if [[ -e $project_dir ]]; then
  if [[ -e "$project_dir/ios" && -e "$project_dir/android" ]]; then

    if [[ -e "$project_dir/example" ]]; then
      log '是flutter plugin项目'
      project_dir=$project_dir/example/ios
    else
      log '是flutter application项目'
      project_dir=$project_dir/ios
    fi

  fi

  cd $project_dir
  # 是否编译工作空间
  workspace_name=$(find . -name *.xcworkspace | awk -F "[/.]" '{print $(NF-1)}')
  # .xcodeproj的名字，如果is_workspace为false，则必须填。否则可不填
  project_name=$(find . -name *.xcodeproj | awk -F "[/.]" '{print $(NF-1)}')

  if [[ -d "$workspace_name" || -d "$project_name" ]]; then
    log '找到ios项目,继续流程'
  else
    log '无法找到ios工程,退出打包'
    exit 1
  fi

  # 检查是否有scheme
  if [[ ! -n $scheme ]]; then
    scheme=$project_name
    echo '默认scheme为' $scheme
    # log "请输入要打包的scheme (Target),不能有错误,默认是主工程scheme"
    # read -r scheme

    # if [[ ! -n $scheme ]]; then
    #   scheme=$project_name
    # fi
  else
    echo '自定义scheme为' $scheme
  fi
  log '开始打包ios'
else
  log '项目路径不存在，退出自动化打包'
  exit 1
fi

# =============项目自定义部分(自定义好下列参数后再执行该脚本)=================== #

# 指定项目的scheme名称（也就是工程的target名称），必填
scheme_name=$scheme

# method，打包的方式。方式分别为 development, ad-hoc, app-store, enterprise 。必填
method="ad-hoc"

if [[ $testflight = 1 ]]; then #如果上传App Store,需要修改method标识
  log 'App Store版本'
  method="app-store"
  log "method: "$method
fi

# 指定要打包编译的方式 : Release,Debug, 必填
build_configuration="Release"

#  下面两个参数只是在手动指定Pofile文件的时候用到，如果使用Xcode自动管理Profile,直接留空就好
# (跟method对应的)mobileprovision文件名，需要先双击安装.mobileprovision文件.手动管理Profile时必填
mobileprovision_name=""

# 项目的bundleID，手动管理Profile时必填
bundle_identifier=""

# =======================脚本的一些固定参数定义(无特殊情况不用修改)====================== #

cd $project_dir

if [ -d "$workspace_name" ]; then
  is_workspace="true"

  if [ -e Podfile ]; then
    echo '存在Podfile'

    #输入pod install或者pod update之后，
    #- CocoaPods首先会去匹配本地spec库；
    #- 在确认spec库不需要更新之后，才会下载相应的库文件；
    #- 这样比较耗时，可使用以下命令，跳过spec版本库更新匹配
    # pod install --verbose --no-repo-update
    pod install
    if [ $? -ne 0 ]; then
      log 'pod install 1 失败'
      pod repo update
      if [ $? -ne 0 ]; then
        log 'pod repo update 2 失败'
        exit 1
      else
        log 'pod repo update 3 完成'
      fi
    else
      log 'pod install 完成'
    fi
  else
    echo '不存在Podfile'
  fi
else
  is_workspace="false"
fi

log "--------------------脚本配置参数检查--------------------"
echo "\033[33;1mis_workspace=${is_workspace} "
log "workspace_name=${workspace_name}"
log "project_name=${project_name}"
log "scheme_name=${scheme_name}"
log "build_configuration=${build_configuration}"
log "bundle_identifier=${bundle_identifier}"
log "method=${method}"
log "mobileprovision_name=${mobileprovision_name} \033[0m"

# 时间
DATE=$(date '+%Y%m%d_%H%M%S')
# 指定输出导出文件夹路径
export_path="$project_dir/Package/$scheme_name"
# 指定输出归档文件路径
export_archive_path="$export_path/$scheme_name.xcarchive"
# 指定输出ipa文件夹路径
export_ipa_path="$export_path"
# 指定输出ipa名称
ipa_name="${scheme_name}_${DATE}"
# 指定导出ipa包需要用到的plist配置文件的路径
export_options_plist_path="$project_dir/ExportOptions.plist"

log "--------------------脚本固定参数检查--------------------"
echo "\033[33;1mproject_dir=${project_dir}"
log "DATE=${DATE}"
log "export_path=${export_path}"
log "export_archive_path=${export_archive_path}"
log "export_ipa_path=${export_ipa_path}"
log "export_options_plist_path=${export_options_plist_path}"
log "ipa_name=${ipa_name} \033[0m"

# =======================自动打包部分(无特殊情况不用修改)====================== #

log "------------------------------------------------------"
echo "\033[32m开始构建项目  \033[0m"
# 进入项目工程目录
cd ${project_dir}
rm -rf ${project_dir}/Package

# 指定输出文件目录不存在则创建
if [ -d "$export_path" ]; then
  log $export_path
else
  mkdir -pv $export_path
fi

# 判断编译的项目类型是workspace还是project
if $is_workspace; then
  # 编译前清理工程
  xcodebuild clean -workspace ${workspace_name}.xcworkspace \
    -scheme ${scheme_name} \
    -configuration ${build_configuration}

  xcodebuild archive -workspace ${workspace_name}.xcworkspace \
    -scheme ${scheme_name} \
    -configuration ${build_configuration} \
    -archivePath ${export_archive_path}
else
  # 编译前清理工程
  xcodebuild clean -project ${project_name}.xcodeproj \
    -scheme ${scheme_name} \
    -configuration ${build_configuration}

  xcodebuild archive -project ${project_name}.xcodeproj \
    -scheme ${scheme_name} \
    -configuration ${build_configuration} \
    -archivePath ${export_archive_path}
fi

#  检查是否构建成功
#  xcarchive 实际是一个文件夹不是一个文件所以使用 -d 判断
if [ -d "$export_archive_path" ]; then
  echo "\033[32;1m项目构建成功 🚀 🚀 🚀  \033[0m"
else
  echo "\033[31;1m项目构建失败 😢 😢 😢  \033[0m"
  exit 1
fi
log "------------------------------------------------------"

if [[ $testflight = 1 ]]; then #如果上传App Store,暂时方案就不用打包App Store了
  open $export_archive_path
  exit 0
fi

echo "\033[32m开始导出ipa文件 \033[0m"

exportArchive() {
  # 先删除export_options_plist文件
  if [ -f "$export_options_plist_path" ]; then
    #log "${export_options_plist_path}文件存在，进行删除"
    rm -f $export_options_plist_path
  fi
  # 根据参数生成export_options_plist文件
  /usr/libexec/PlistBuddy -c "Add :method String ${method}" $export_options_plist_path
  # /usr/libexec/PlistBuddy -c  "Add :provisioningProfiles:"  $export_options_plist_path
  # /usr/libexec/PlistBuddy -c  "Add :provisioningProfiles:${bundle_identifier} String ${mobileprovision_name}"  $export_options_plist_path
  /usr/libexec/PlistBuddy -c "Add :signingStyle String automatic" $export_options_plist_path
  /usr/libexec/PlistBuddy -c "Add :destination String export" $export_options_plist_path
  /usr/libexec/PlistBuddy -c "Add :compileBitcode bool false" $export_options_plist_path
  # 修改的命令   把 Add 改为 set

  xcodebuild -exportArchive \
    -archivePath ${export_archive_path} \
    -exportPath ${export_ipa_path} \
    -exportOptionsPlist ${export_options_plist_path} \
    -allowProvisioningUpdates

  # 先删除export_options_plist文件
  if [ -f "$export_options_plist_path" ]; then
    #log "${export_options_plist_path}文件存在，进行删除"
    rm -f $export_options_plist_path
  fi
}

failedTimes=0
handleExportArchiveFail() {
  if [[ $failedTimes == 3 ]]; then
    log '最大失败循环够了,退出'
    open $export_archive_path
    log "\033[31;1mexportArchive ipa包失败 1 😢 😢 😢     \033[0m"
    exit 1
  else
    log '我去自动重新调用了'
    failedTimes=$(($failedTimes + 1)) # ((failedTimes++))
    exportArchive
  fi
}

exportArchive

ipaPath=$(find ${export_ipa_path} -name '*ipa')

# 检查ipa文件是否存在
if [ -f "$ipaPath" ]; then
  echo "\033[32;1mexportArchive ipa包成功,准备进行重命名\033[0m"
  if [ $failedTimes=0 ]; then
    echo "\033[33;1mexportArchive ipa包,漂亮一遍过\033[0m"
  else
    echo "\033[33;1mexportArchive ipa包,重复次数 : $failedTimes\033[0m"
  fi
else
  handleExportArchiveFail
fi

# 修改ipa文件名称
mv $ipaPath $export_ipa_path/$ipa_name.ipa

# 检查文件是否存在
if [ -f "$export_ipa_path/$ipa_name.ipa" ]; then
  echo "\033[32;1m导出 ${ipa_name}.ipa 包成功 🎉  🎉  🎉   \033[0m"
  # open $export_path
else
  open $export_archive_path
  echo "\033[31;1m导出 ${ipa_name}.ipa 包失败 2 😢 😢 😢     \033[0m"
  exit 1
fi

# 删除export_options_plist文件（中间文件）
if [ -f "$export_options_plist_path" ]; then
  #log "${export_options_plist_path}文件存在，准备删除"
  rm -f $export_options_plist_path
fi

ipaPath=$export_ipa_path/$ipa_name.ipa

echo "\033[33;1mipa路径: $ipaPath\033[0m"

# 输出打包总用时
echo "\033[36;1m使用ios自动打包用时: ${SECONDS}s \033[0m"

exit 0
