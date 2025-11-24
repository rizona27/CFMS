#!/bin/bash

# Xcode项目自动打包脚本
# 使用方法：在项目根目录执行 ./build.sh

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="CFMS"
SCHEME="CFMS"
CONFIGURATION="Release"  # 可以改为 Release，Debug
EXPORT_OPTIONS_PLIST="ExportOptions.plist"
ENTITLEMENTS_FILE="CFMS/App/CFMS.entitlements"  # 修正路径
INFO_PLIST="CFMS/App/Info.plist"  # 修正路径

# 输出目录
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"

# 清理函数
cleanup() {
    echo -e "${YELLOW}清理构建目录...${NC}"
    rm -rf ${BUILD_DIR}
}

# 检查必要文件
check_required_files() {
    echo -e "${YELLOW}检查必要文件...${NC}"
    
    if [ ! -f "${EXPORT_OPTIONS_PLIST}" ]; then
        echo -e "${RED}错误: 找不到 ${EXPORT_OPTIONS_PLIST}${NC}"
        exit 1
    fi
    
    if [ ! -f "${ENTITLEMENTS_FILE}" ]; then
        echo -e "${RED}错误: 找不到 ${ENTITLEMENTS_FILE}${NC}"
        exit 1
    fi
    
    if [ ! -f "${INFO_PLIST}" ]; then
        echo -e "${RED}错误: 找不到 ${INFO_PLIST}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}所有必要文件都存在${NC}"
}

# 归档项目
archive_project() {
    echo -e "${YELLOW}开始归档项目...${NC}"
    
    # 检查项目文件类型（.xcodeproj 或 .xcworkspace）
    if [ -d "${PROJECT_NAME}.xcworkspace" ]; then
        echo -e "${GREEN}使用 workspace 文件${NC}"
        xcodebuild archive \
            -workspace "${PROJECT_NAME}.xcworkspace" \
            -scheme "${SCHEME}" \
            -configuration "${CONFIGURATION}" \
            -archivePath "${ARCHIVE_PATH}" \
            -destination "generic/platform=iOS" \
            CODE_SIGN_STYLE="Automatic" \
            DEVELOPMENT_TEAM="8QXX7UMS83"
    elif [ -d "${PROJECT_NAME}.xcodeproj" ]; then
        echo -e "${GREEN}使用 project 文件${NC}"
        xcodebuild archive \
            -project "${PROJECT_NAME}.xcodeproj" \
            -scheme "${SCHEME}" \
            -configuration "${CONFIGURATION}" \
            -archivePath "${ARCHIVE_PATH}" \
            -destination "generic/platform=iOS" \
            CODE_SIGN_STYLE="Automatic" \
            DEVELOPMENT_TEAM="8QXX7UMS83"
    else
        echo -e "${RED}错误: 找不到项目文件 (.xcodeproj 或 .xcworkspace)${NC}"
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}归档失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}项目归档成功: ${ARCHIVE_PATH}${NC}"
}

# 导出IPA
export_ipa() {
    echo -e "${YELLOW}开始导出IPA...${NC}"
    
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
        -exportPath "${EXPORT_PATH}" \
        -allowProvisioningUpdates
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}导出IPA失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}IPA导出成功: ${EXPORT_PATH}${NC}"
}

# 显示构建信息
show_build_info() {
    echo -e "\n${GREEN}=== 构建信息 ===${NC}"
    echo -e "项目名称: ${PROJECT_NAME}"
    echo -e "Scheme: ${SCHEME}"
    echo -e "配置: ${CONFIGURATION}"
    echo -e "归档路径: ${ARCHIVE_PATH}"
    echo -e "导出路径: ${EXPORT_PATH}"
    echo -e "Team ID: 8QXX7UMS83"
    
    # 显示生成的IPA文件
    if [ -d "${EXPORT_PATH}" ]; then
        echo -e "\n${GREEN}生成的文件:${NC}"
        ls -la "${EXPORT_PATH}/"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}开始构建 ${PROJECT_NAME}...${NC}"
    
    # 检查必要文件
    check_required_files
    
    # 清理旧构建
    cleanup
    
    # 创建构建目录
    mkdir -p ${BUILD_DIR}
    
    # 归档项目
    archive_project
    
    # 导出IPA
    export_ipa
    
    # 显示构建信息
    show_build_info
    
    echo -e "\n${GREEN}🎉 构建完成！${NC}"
    echo -e "IPA文件位置: ${EXPORT_PATH}/${SCHEME}.ipa"
}

# 执行主函数
main