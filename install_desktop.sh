#!/bin/bash

# 定义颜色代码
INFO='\033[0;36m'    # 青色
WARNING='\033[0;33m' # 黄色
ERROR='\033[0;31m'   # 红色
SUCCESS='\033[0;32m' # 绿色
NC='\033[0m'       # 无颜色

# --- AdsPower 设置 ---
# !!! 重要: 请检查下面的 URL 是否为 AdsPower 的最新或您需要的版本 !!!
# 如果需要更新，请只修改这里的 URL
ADSPOWER_DEB_URL="https://version.adspower.net/software/linux-x64-global/AdsPower-Global-5.9.14-x64.deb"
# 从 URL 中自动提取文件名
ADSPOWER_DEB_FILENAME=$(basename "$ADSPOWER_DEB_URL")
# --- End AdsPower 设置 ---

# 提示输入用户名和密码
while true; do
    read -p "请输入远程桌面的用户名: " USER
    if [[ "$USER" == "root" ]]; then
        echo -e "${ERROR}错误: 'root' 不能作为用户名。请使用其他用户名。${NC}"
    elif [[ "$USER" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}错误: 用户名包含非法字符。仅允许字母和数字。${NC}"
    else
        break
    fi
done

while true; do
    read -sp "请输入 $USER 的密码: " PASSWORD
    echo
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        echo -e "${ERROR}错误: 密码包含非法字符。仅允许字母和数字。${NC}"
    else
        break
    fi
done

# 更新软件包列表
echo -e "${INFO}正在更新软件包列表...${NC}"
sudo apt update

# 安装依赖: curl 用于下载, gdebi 用于安装 .deb 包并处理依赖
echo -e "${INFO}正在安装 curl 和 gdebi-core (用于下载和安装 AdsPower)...${NC}"
sudo apt install -y curl gdebi-core

# 安装 XFCE 核心组件和 XRDP
echo -e "${INFO}正在安装 XFCE 轻量桌面环境 (核心组件)...${NC}"
sudo apt install -y xfce4 xfce4-goodies --no-install-recommends

echo -e "${INFO}正在安装 XRDP 远程桌面服务...${NC}"
sudo apt install -y xrdp

# 创建用户并设置密码
echo -e "${INFO}正在添加用户 $USER 并设置密码...${NC}"
sudo useradd -m -s /bin/bash $USER
echo "$USER:$PASSWORD" | sudo chpasswd

echo -e "${INFO}将 $USER 添加到 sudo 组 (允许执行管理员命令)...${NC}"
sudo usermod -aG sudo $USER

# 配置 XRDP 使用 XFCE
echo -e "${INFO}配置 XRDP 使用 XFCE 桌面...${NC}"
echo "xfce4-session" | sudo tee /home/$USER/.xsession
sudo chown $USER:$USER /home/$USER/.xsession

echo -e "${INFO}调整 XRDP 配置 (降低颜色深度)...${NC}"
sudo sed -i 's/^Max Bpp=32/Max Bpp=16/' /etc/xrdp/xrdp.ini
echo -e "${SUCCESS}XRDP 配置已尝试更新为较低颜色深度。${NC}"

echo -e "${INFO}正在重启 XRDP 服务以应用配置...${NC}"
sudo systemctl restart xrdp

echo -e "${INFO}设置 XRDP 服务开机自启...${NC}"
sudo systemctl enable xrdp

# 下载 AdsPower .deb 软件包
echo -e "${INFO}正在下载 AdsPower 软件包 ($ADSPOWER_DEB_FILENAME)...${NC}"
echo -e "${WARNING}使用的下载链接是: $ADSPOWER_DEB_URL${NC}"
echo -e "${WARNING}如果此版本过旧或不正确, 请修改脚本顶部的 ADSPOWER_DEB_URL 变量。${NC}"
# 使用 curl 下载，-L 跟随重定向，-O 使用服务器上的文件名保存
curl -L -O "$ADSPOWER_DEB_URL"
if [ $? -ne 0 ]; then
    echo -e "${ERROR}下载 AdsPower 失败。请检查 URL 是否有效或网络连接。${NC}"
    exit 1
fi
if [ ! -f "$ADSPOWER_DEB_FILENAME" ]; then
     echo -e "${ERROR}下载 AdsPower 后未找到文件 $ADSPOWER_DEB_FILENAME。${NC}"
     exit 1
fi

# 使用 gdebi 安装 AdsPower (自动处理依赖)
echo -e "${INFO}使用 gdebi 安装 AdsPower ($ADSPOWER_DEB_FILENAME)...${NC}"
sudo gdebi -n "$ADSPOWER_DEB_FILENAME"
if [ $? -ne 0 ]; then
    echo -e "${ERROR}安装 AdsPower 失败。请检查下载的文件 '$ADSPOWER_DEB_FILENAME' 或依赖项问题。${NC}"
    # exit 1 # 选择性退出，或者继续执行后面的步骤
fi

# 确保桌面目录存在 (为快捷方式做准备)
DESKTOP_DIR="/home/$USER/Desktop"
if [ ! -d "$DESKTOP_DIR" ]; then
    echo -e "${INFO}桌面目录不存在。正在为 $USER 创建桌面目录 ($DESKTOP_DIR)...${NC}"
    # 使用 sudo 创建，并确保所有权正确
    sudo mkdir -p "$DESKTOP_DIR"
    sudo chown $USER:$USER "$DESKTOP_DIR"
    # 设置权限确保用户可以写入
    sudo chmod 755 "$DESKTOP_DIR"
fi

# 创建 AdsPower 的桌面快捷方式
DESKTOP_FILE="$DESKTOP_DIR/AdsPower.desktop"
echo -e "${INFO}正在创建 AdsPower 的桌面快捷方式 ($DESKTOP_FILE)...${NC}"

# 使用 tee 创建 .desktop 文件，注意权限
sudo tee "$DESKTOP_FILE" > /dev/null <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=AdsPower
Comment=启动 AdsPower
# 假设 AdsPower 安装在 /opt/AdsPower/
Exec=/opt/AdsPower/AdsPower %U
Icon=/opt/AdsPower/resources/app/static/icon.png
Terminal=false
StartupNotify=true
Categories=Network;WebBrowser;Utility;
EOL

# 设置桌面文件的权限和所有者
sudo chmod +x "$DESKTOP_FILE"
sudo chown $USER:$USER "$DESKTOP_FILE"
if [ $? -eq 0 ]; then
     echo -e "${SUCCESS}AdsPower 桌面快捷方式已创建。${NC}"
else
     echo -e "${ERROR}创建 AdsPower 桌面快捷方式失败。请检查 $DESKTOP_DIR 权限。${NC}"
fi

# 清理下载的 .deb 文件 (可选)
if [ -f "$ADSPOWER_DEB_FILENAME" ]; then
    echo -e "${INFO}正在清理下载的 AdsPower 安装包 ($ADSPOWER_DEB_FILENAME)...${NC}"
    rm -f "$ADSPOWER_DEB_FILENAME"
fi

# 获取服务器 IP 地址
IP_ADDR=$(hostname -I | awk '{print $1}')

# 最终提示信息
echo -e "${SUCCESS}安装完成！已安装 XFCE 核心桌面, XRDP 服务, 以及 AdsPower。${NC}" # 更新了消息
echo -e "${INFO}您现在可以使用标准 RDP 客户端通过以下信息进行远程桌面连接:${NC}"
echo -e "${INFO}IP 地址: ${SUCCESS}$IP_ADDR${NC}"
echo -e "${INFO}用户名: ${SUCCESS}$USER${NC}"
echo -e "${INFO}密码: ${SUCCESS}$PASSWORD${NC}"
echo -e "${WARNING}首次登录 XFCE 可能需要您手动配置面板。AdsPower 已安装并应该有桌面快捷方式。${NC}" # 更新了警告

# 提示重启
echo -e "${INFO}建议重启系统以确保所有更改生效。您可以稍后手动执行 'sudo reboot'。${NC}"
# sudo reboot

exit 0
