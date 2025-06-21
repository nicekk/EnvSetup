#!/bin/bash
# MySQL 5.7 一键安装脚本
# 使用方法: chmod +x mysql_setup.sh && ./mysql_setup.sh

echo "=========================================="
echo "MySQL 5.7 一键安装脚本"
echo "=========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 检查MySQL是否已经安装
if rpm -qa | grep -q mysql-community-server; then
    echo "MySQL 已经安装，跳过安装步骤..."
    MYSQL_INSTALLED=true
else
    MYSQL_INSTALLED=false
fi

# 1. 安装 MySQL（如果未安装）
if [ "$MYSQL_INSTALLED" = false ]; then
    echo "1. 安装 MySQL 5.7..."
    
    # 下载并安装MySQL仓库
    wget https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
    rpm -ivh mysql57-community-release-el7-11.noarch.rpm
    
    # 导入MySQL GPG密钥
    echo "导入MySQL GPG密钥..."
    rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
    
    # 安装MySQL（跳过GPG检查）
    yum install -y mysql-community-server --nogpgcheck
    
    # 检查安装是否成功
    if [ $? -ne 0 ]; then
        echo "MySQL 安装失败，尝试其他方法..."
        # 尝试使用rpm直接安装
        yum install -y mysql-community-server --nogpgcheck --force
        if [ $? -ne 0 ]; then
            echo "MySQL 安装失败，请检查网络连接和yum源配置"
            exit 1
        fi
    fi
else
    echo "1. MySQL 已安装，跳过安装步骤..."
fi

# 2. 检查MySQL数据目录是否已初始化
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "2. 初始化 MySQL..."
    mysqld --initialize-insecure --user=mysql
else
    echo "2. MySQL 数据目录已存在，跳过初始化..."
fi

# 3. 启动 MySQL 服务
echo "3. 启动 MySQL 服务..."
# 尝试不同的服务名称
if systemctl list-unit-files | grep -q mysqld.service; then
    SERVICE_NAME="mysqld"
elif systemctl list-unit-files | grep -q mysql.service; then
    SERVICE_NAME="mysql"
else
    echo "未找到MySQL服务，尝试启动mysqld..."
    SERVICE_NAME="mysqld"
fi

# 检查服务是否已经在运行
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "MySQL 服务已经在运行..."
else
    systemctl start $SERVICE_NAME
    systemctl enable $SERVICE_NAME
    
    # 检查服务是否启动成功
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        echo "MySQL 服务启动失败"
        systemctl status $SERVICE_NAME
        exit 1
    fi
fi

# 4. 等待服务完全启动
echo "4. 等待服务完全启动..."
sleep 5

# 5. 检查日志文件
echo "5. 检查日志文件..."
LOG_FILE="/var/log/mysqld.log"
if [ ! -f "$LOG_FILE" ]; then
    echo "日志文件不存在，尝试其他位置..."
    LOG_FILE="/var/log/mysql/error.log"
    if [ ! -f "$LOG_FILE" ]; then
        echo "未找到MySQL日志文件，使用空密码初始化"
        TEMP_PASSWORD=""
    fi
else
    # 获取临时密码（如果存在）
    TEMP_PASSWORD=$(grep 'temporary password' $LOG_FILE 2>/dev/null | awk '{print $NF}' | tail -1)
    if [ -z "$TEMP_PASSWORD" ]; then
        echo "未找到临时密码，使用空密码"
        TEMP_PASSWORD=""
    fi
fi

echo "临时密码: $TEMP_PASSWORD"

# 6. 检查root密码是否已经设置
echo "6. 检查root密码配置..."
# 尝试无密码连接
if mysql -u root -e "SELECT 1;" 2>/dev/null; then
    echo "root用户可以使用空密码连接"
    ROOT_PASSWORD_SET=false
else
    echo "root用户需要密码"
    ROOT_PASSWORD_SET=true
fi

# 7. 配置新密码（如果需要）
if [ "$ROOT_PASSWORD_SET" = false ]; then
    echo "7. 配置新密码..."
    read -s -p "请输入新的 root 密码: " NEW_PASSWORD
    echo ""
    
    # 安全配置
    echo "8. 执行安全配置..."
    mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
else
    echo "7. root密码已设置，跳过密码配置..."
    read -s -p "请输入当前的 root 密码: " NEW_PASSWORD
    echo ""
fi

# 8. 创建应用数据库
echo "9. 创建应用数据库..."
DB_NAME="gzh_money"
DB_USER="gzh_user"
DB_PASSWORD="GzhPassword123!"

# 检查数据库是否已存在
if mysql -u root -p$NEW_PASSWORD -e "USE $DB_NAME;" 2>/dev/null; then
    echo "数据库 $DB_NAME 已存在，跳过创建..."
else
    mysql -u root -p$NEW_PASSWORD << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
fi

# 9. 创建管理脚本
echo "10. 创建管理脚本..."
cat > mysql_manager.sh << EOF
#!/bin/bash
SERVICE_NAME="$SERVICE_NAME"
ROOT_PASSWORD="$NEW_PASSWORD"
DB_NAME="$DB_NAME"
LOG_FILE="$LOG_FILE"

case "\$1" in
    start) systemctl start \$SERVICE_NAME ;;
    stop) systemctl stop \$SERVICE_NAME ;;
    restart) systemctl restart \$SERVICE_NAME ;;
    status) systemctl status \$SERVICE_NAME ;;
    logs) tail -f \$LOG_FILE ;;
    backup) mysqldump -u root -p\$ROOT_PASSWORD \$DB_NAME > backup_\$(date +%Y%m%d_%H%M%S).sql ;;
    connect) mysql -u root -p\$ROOT_PASSWORD ;;
    *) echo "Usage: \$0 {start|stop|restart|status|logs|backup|connect}" ;;
esac
EOF

chmod +x mysql_manager.sh

echo "=========================================="
echo "MySQL 5.7 配置完成！"
echo "=========================================="
echo "Root 密码: $NEW_PASSWORD"
echo "数据库名: $DB_NAME"
echo "应用用户: $DB_USER"
echo "应用密码: $DB_PASSWORD"
echo "服务名称: $SERVICE_NAME"
echo ""
echo "管理命令:"
echo "  ./mysql_manager.sh start   - 启动"
echo "  ./mysql_manager.sh stop    - 停止"
echo "  ./mysql_manager.sh restart - 重启"
echo "  ./mysql_manager.sh status  - 状态"
echo "  ./mysql_manager.sh logs    - 日志"
echo "  ./mysql_manager.sh backup  - 备份"
echo "  ./mysql_manager.sh connect - 连接数据库"
echo "=========================================="