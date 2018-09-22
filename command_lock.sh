#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    command_lock.sh
# Revision:    1.0
# Date:        2018/09/22
# Author:      ImDong <www@qs5.org>
# Website:     https://www.qs5.org
# Description: Command exclusive operation lock under Linux
# Github:      https://github.com/imdong/Linux-Command-Lock
# -------------------------------------------------------------------------------
# Copyright:   2018 (c) ImDong
# License:     Apache
# -------------------------------------------------------------------------------

###### 自定义配置区域，不熟悉建议留空即可，默认配置以git为例 ######

# 被接管的命令名(留空则获取自身文件名)
COMMAND_NAME="git"

# 需要被锁定接管的参数名(竖线隔开|正则表达式规则)
COMMAND_LOCK_ARGS="^(checkout|pull|push|merge)( |$)"

# 临时锁有效时间 (单位: s/秒)
COMMAND_LOCK_TEMP_TIME=120

# 原始被执行文件名(留空自动搜索)
COMMAND_SOURCE_FILE=""

# 定义锁文件目录(/var/run 目录MacOS下可能没权限,建议使用/tmp)
COMMAND_LOCK_FILE_DIR="/tmp"

# 手动锁定参数名
COMMAND_LOCK="lock"

# 手动解锁参数名
COMMAND_UNLOCK="unlock"

# 获取用户session_id (其实就是用户bash pid)
SESSION_ID=${PPID}

###### 自定义配置结束 下面不要更改 ######

# 设定相关空值得默认值
if [ ! "${COMMAND_NAME}" ]; then
    COMMAND_NAME=${BASH_SOURCE[0]##*/};
fi
COMMAND_LOCK_FILE="${COMMAND_LOCK_FILE_DIR}/command_lock_${COMMAND_NAME}"

# 获取文件最终修改时间
function get_file_modify_time()
{
    # 获取检测的文件名
    FILE_NAME=${1}
    # 根据系统不同分别处理
    sysOS=`uname -s`
    if [ ${sysOS} == "Darwin" ];then
        LOCK_TIME=`stat -f %m "${COMMAND_LOCK_FILE}.pid"`
    elif [ ${sysOS} == "Linux" ];then
        LOCK_TIME=`stat -c %Y "${COMMAND_LOCK_FILE}.pid"`
    else
        LOCK_TIME=`stat -c %Y "${COMMAND_LOCK_FILE}.pid"`
    fi

    return ${LOCK_TIME}
}

# 格式化时间
function format_time2str()
{
    # 获取时间
    FORMAT_TIME=${1}
    FORMAT_STR=${2}

    # 根据系统不同分别处理
    sysOS=`uname -s`
    if [ ${sysOS} == "Darwin" ];then
        TIME_STR=`date -r${FORMAT_TIME} "${FORMAT_STR}"`
    elif [ ${sysOS} == "Linux" ];then
        TIME_STR=`date -d @${FORMAT_TIME} "${FORMAT_STR}"`
    else
        TIME_STR=`date -d @${FORMAT_TIME} "${FORMAT_STR}"`
    fi

    return 1
}

# 获取锁id
function lock_get_id()
{
    # 设置默认值
    LOCK_ID=0;

    # 锁定类型 0未锁定 -1手动锁 大于0 锁定时间
    LOCK_TYPE=0;

    # 检测手动锁
    if [ -f "${COMMAND_LOCK_FILE}.lock" ]; then
        LOCK_ID=$(cat "${COMMAND_LOCK_FILE}.lock");
        LOCK_TYPE=-1;
        # 获取锁定创建时间
        get_file_modify_time "${COMMAND_LOCK_FILE}.lock"
        return 1;
    fi

    # 检测临时锁
    if [ -f "${COMMAND_LOCK_FILE}.pid" ]; then
        # 获取临时锁 产生时间
        get_file_modify_time "${COMMAND_LOCK_FILE}.pid"
        LOCAL_TIME=`date +%s`

        # 小于指定时间则锁生效
        if [ $[ ${LOCAL_TIME} - ${LOCK_TIME} ] -lt ${COMMAND_LOCK_TEMP_TIME} ]; then
            LOCK_ID=$(cat "${COMMAND_LOCK_FILE}.pid");
            LOCK_TYPE=$[ $LOCAL_TIME - $LOCK_TIME ];
        fi

        return 1;
    fi
}

# 检查锁文件
function lock_check()
{
    # 获取锁ID
    lock_get_id;

    # 未锁定或为锁定者则 更新锁定 然后返回放行
    if [ ${LOCK_ID} -le 0 ] || [ ${LOCK_ID} -eq ${SESSION_ID} ]; then
        echo ${SESSION_ID} > "${COMMAND_LOCK_FILE}.pid";
        return 0;
    fi

    # 提示被锁定
    format_time2str ${LOCK_TIME} "+%Y-%m-%d %H:%m:%S";

    # 根据锁定类型不同显示不同的提示
    if [ ${LOCK_TYPE} -lt 0 ]; then
        echo "${COMMAND_NAME} 已于 ${TIME_STR} 被手动锁定";
    else
        echo "未执行，${COMMAND_NAME} 在 ${LOCK_TYPE} 秒内活跃 (${COMMAND_LOCK_TEMP_TIME}秒未操作自动解锁)";
    fi

    echo "强制解锁执行 ${COMMAND_NAME} ${COMMAND_UNLOCK} ${LOCK_ID}";
    exit 0;
}

# 设置锁定
function lock_set()
{
    # 检查是否已经被锁定
    lock_check;

    # 设置锁
    echo ${SESSION_ID} > "${COMMAND_LOCK_FILE}.lock";
    echo "${COMMAND_NAME} 操作锁定设置成功"
    echo "操作完成后记得执行 ${COMMAND_NAME} ${COMMAND_UNLOCK} 进行解锁。"
}

# 操作解锁
function lock_unset()
{
    # 获取参数ID
    UNLOCK_ID=0;
    if [ "${2}" ]; then
        UNLOCK_ID=${2}
    fi

    # 获取锁定ID
    lock_get_id;

    # 判断是否锁定
    if [ ${LOCK_ID} -eq 0 ]; then
        echo "${COMMAND_NAME} 未被锁定"
        return 0;
    fi

    # 解锁参数是否正确
    if [ ${LOCK_ID} -eq ${SESSION_ID} ] || [ ${LOCK_ID} -eq ${UNLOCK_ID} ]; then
        rm -f "${COMMAND_LOCK_FILE}.lock"
        rm -f "${COMMAND_LOCK_FILE}.pid"
        echo "${COMMAND_NAME} 解除锁定操作成功"
        return 1;
    else
        echo "未能解锁，非锁定者本人操作"
        echo "强制解锁执行 ${COMMAND_NAME} ${COMMAND_UNLOCK} ${LOCK_ID}";
    fi
}

###### 逻辑处理 ######

# 判断命令
case ${1} in
    # 手动锁定
    ${COMMAND_LOCK})
        lock_set 1
        exit 1
        ;;
    # 手动解锁
    ${COMMAND_UNLOCK})
        lock_unset $@
        exit 1
        ;;
    # 通过正则表达式匹配命令是否符合上面的规则
    *)
        if [[ "${@}" =~ ${COMMAND_LOCK_ARGS} ]]; then
            # 检测锁定
            lock_check $@
        fi
        ;;
esac

# 如果原始命令留空则遍历目录找能执行的文件
if [ ! "${COMMAND_SOURCE_FILE}" ]; then
    PATH_LIST=${PATH//:/ }
    for PATH_ITEM in ${PATH_LIST}
    do
        # 判断文件存在且不是自身
        COMMAND_FILE_NAME="${PATH_ITEM}/${COMMAND_NAME}";
        if [ -f "${COMMAND_FILE_NAME}" ] && [ "${COMMAND_FILE_NAME}" != "${BASH_SOURCE[0]}" ]; then
            COMMAND_SOURCE_FILE="${COMMAND_FILE_NAME}";
            break;
        fi
    done
fi

# 如果未能正确定义原始文件则不在执行 [ ! "${COMMAND_SOURCE_FILE}" ]  ||
if [ ! "${COMMAND_SOURCE_FILE}" ] || [ ! -f "${COMMAND_SOURCE_FILE}" ]; then
    echo "未能找到 ${COMMAND_NAME} 对应的原始文件，请手动配置正确的文件。"
    exit;
fi

# 调用原有执行
${COMMAND_SOURCE_FILE} $@
exit $?
