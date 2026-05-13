#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - ТОЛЬКО КЛЮЧИ И БЕЗОПАСНОСТЬ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo "========================================="
echo "     SSH HARDENING SCRIPT"
echo "========================================="

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Запустите от root: sudo bash $0${NC}"
    exit 1
fi

echo ""
echo "=== НАСТРОЙКА КЛЮЧЕЙ И БЕЗОПАСНОСТИ ==="

# Подменю ключей
echo ""
echo "1) Скачать с GitHub (@mrpltrans)"
echo "2) Вставить публичный ключ вручную"
echo "3) Пропустить"
echo ""
read -p "Выберите [1-3]: " KEY_OPT

case $KEY_OPT in
    1)
        echo ""
        echo "Скачиваем ключи с GitHub..."
        mkdir -p /root/.ssh
        curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключи загружены${NC}"
        ;;
    2)
        echo ""
        echo "Вставьте публичный SSH ключ:"
        read USER_KEY
        mkdir -p /root/.ssh
        echo "$USER_KEY" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключ сохранён${NC}"
        ;;
    3)
        echo ""
        echo -e "${YELLOW}⏭️ Пропускаем установку ключей${NC}"
        ;;
esac

# Показываем ключи если есть
if [ -s /root/.ssh/authorized_keys ] && [ "$KEY_OPT" != "3" ]; then
    echo ""
    echo -e "${GREEN}Установленные ключи:${NC}"
    echo "────────────────────────────────────────"
    cat /root/.ssh/authorized_keys
    echo "────────────────────────────────────────"
fi

# Безопасность
echo ""
echo "Отключаем вход по паролю..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config

systemctl restart ssh
echo -e "${GREEN}✅ Пароли отключены, вход только по ключам${NC}"

# Финальный вывод
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ НАСТРОЙКА ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "Подключение: ${CYAN}ssh root@$IP${NC}"
echo ""
