#!/bin/bash
# CentOS 环境配置脚本
# 使用方法: chmod +x centos_setup.sh && ./centos_setup.sh

echo "=========================================="
echo "开始配置 CentOS 开发环境..."
echo "=========================================="

# 更新系统包
echo "1. 更新系统包..."
sudo yum update -y

# 安装基础工具
echo "2. 安装基础工具..."
sudo yum install -y wget curl unzip vim net-tools

# 1. 安装 JDK 1.8
echo "3. 安装 JDK 1.8..."
sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

# 设置 JAVA_HOME
echo "4. 配置 JAVA_HOME..."
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME: $JAVA_HOME_PATH"
echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc

# 2. 安装 Maven
echo "5. 安装 Maven..."
cd /tmp
wget https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz
sudo tar -xzf apache-maven-3.8.8-bin.tar.gz -C /opt
sudo ln -sf /opt/apache-maven-3.8.8 /opt/maven

# 设置 Maven 环境变量
echo "6. 配置 Maven 环境变量..."
echo 'export MAVEN_HOME=/opt/maven' >> ~/.bashrc
echo 'export PATH=$MAVEN_HOME/bin:$PATH' >> ~/.bashrc

# 3. 安装 Git
echo "7. 安装 Git..."
sudo yum install -y git

# 4. 安装 Node.js
echo "8. 安装 Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# 重新加载环境变量
echo "9. 重新加载环境变量..."
source ~/.bashrc

# 验证安装
echo "=========================================="
echo "验证安装结果..."
echo "=========================================="
echo "Java 版本:"
java -version
echo ""
echo "Maven 版本:"
mvn -version
echo ""
echo "Git 版本:"
git --version
echo ""
echo "Node.js 版本:"
node --version
echo ""
echo "npm 版本:"
npm --version
echo ""

echo "=========================================="
echo "环境配置完成！"
echo "=========================================="