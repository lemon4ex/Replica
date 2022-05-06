#!/bin/bash

# -----------------------------------------------------------------------
# Replica -- iOS Resign Tool
# Copyright (C) 2017-2018 h4ck (https://ymlab.net)
# -----------------------------------------------------------------------

# 此函数请勿修改
function panic() # args: exitCode, message...
{
    local exitCode=$1
    set +e
    
    shift
    [[ "$@" == "" ]] || \
        echo "$@" >&2

    exit $exitCode
}

# -------------------------
# 重签之前调用此函数，可在此函数中拷贝需要的文件到应用包内，注入动态库到指定可执行文件等
# 参数如下：
# $1: 原文件输入路径，如：/Users/h4ck/Downloads/Payload.ipa
# $2: 重签前.app目录路径，如：/var/folders/mq/378q436x625125_n02xbzc340000gn/T/net.ymlab.dev.Replica.AyoxrFq8/out/Payload/WeChat.app，通常使用此路径进行操作
#
# 请在此函数内编写自定义的脚本代码
function before()
{
    ## 一个栗子
    ## 获取当前脚本所在目录路径
    # basepath=$(cd `dirname $0`; pwd)

    ## 拷贝需要的文件到APP内
    # cp -rf "${basepath}/uc.dat" "$2/uc.dat"
    # cp -rf "${basepath}/AFNetworking.framework" "$2/Frameworks/AFNetworking.framework"

    ## 将指定动态库注入到目标二进制内
    # optool install -p "@rpath/AFNetworking.framework/AFNetworking" -t "$2/WeChat"

    echo "$@"
    panic 0 "调用 before"
}

# 重签之后调用此函数，可在此函数中重命名生成的文件，拷贝生成的文件到指定路径等
# 参数如下：
# $1: 原文件输入路径，如：/Users/h4ck/Downloads/Payload.ipa
# $2: 重签后文件保存路径，文件格式可能为ipa或app，如：/Users/h4ck/Desktop/Payload_resign.ipa
#
# 请在此函数内编写自定义的脚本代码
function after()
{
    echo "$@"
    panic 0 "调用 after"
}
# -------------------------

# Replica 将会调用此脚本，传入before和after参数，分别在重签开始前和重签完成后调用
if [[ "$1" == "before" ]]; then
    before "$2" "$3"
else
    after "$2" "$3"
fi