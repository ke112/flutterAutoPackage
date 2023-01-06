#!/bin/bash
###
# @Author: zhangzhihua 54562841@qq.com
# @Date: 2021-12-15 20:29:27
# @LastEditors: zhangzhihua
# @LastEditTime: 2022-11-26 20:07:23
###
#--------------------------------------------
# 清理Mac垃圾缓存脚本
#--------------------------------------------

echo "========开始清除Xcode缓存========"
old=$(df -hl $BASEHOME | awk 'NR==2{print $4}' | sed 's/G//g')

echo "-- 移除对旧设备的支持"
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/

echo "-- 移除 Xcode 运行安装 APP 产生的缓存文件(DerivedData)"
rm -rf ~/Library/Developer/Xcode/DerivedData/

echo "-- 移除 APP 打包的ipa历史版本(Archives)"
rm -rf ~/Library/Developer/Xcode/Archives/

echo "-- 移除 APP 打包的app icon历史版本(Archives)"
rm -rf ~/Library/Developer/Xcode/Products/

# echo "5 -- 移除模拟器的缓存数据(Devices)(需重启Xcode)"
# rm -rf ~/Library/Developer/CoreSimulator/Devices

# echo "6 -- 移除描述文件(Provisioning Profiles)"
# rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/

echo "-- 移除模拟器缓存"
rm -rf ~/Library/Developer/CoreSimulator/Caches/

# echo "8 -- 移除旧版本的模拟器支持"
# rm -rf ~/Library/Developer/CoreSimulator/Profiles/Runtimes/

echo "-- 移除 playground 的项目缓存(XCPGDevices)"
rm -rf ~/Library/Developer/XCPGDevices/

rm -rf .zsh_history #删除zsh命令

echo "-- 移除 模拟器中安装的应用数据"
xcrun simctl delete unavailable

# echo "-- 移除 swiftUI预览的模拟器和数据"
# xcrun simctl --set previews delete unavailable

echo "====   Xcode清除完毕   ===="
echo

# 不能打开,否则还得执行 flutter precache --ios ,下载ios tools
# rm -fr /Users/ke/Documents/flutter/bin/cache
# rm -fr /Users/ke/Documents/flutter_3.0.5/bin/cache
# rm -fr /Users/ke/Documents/flutter_2.10.5/bin/cache
# rm -fr /Users/ke/Documents/flutter_2.8.1/bin/cache
# rm -fr /Users/ke/Documents/flutter_2.5.3/bin/cache
# echo "====   flutter sdk缓存清除完毕   ===="

echo "====   Mac缓存清除完毕   ===="
echo

new=$(df -hl $BASEHOME | awk 'NR==2{print $4}' | sed 's/G//g')

reduce=$(($new - $old))
echo 本次清理了${reduce}个G
