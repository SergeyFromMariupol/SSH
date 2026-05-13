#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - ПРОСТАЯ И НАДЁЖНАЯ ВЕРСИЯ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}        🚀 SSH HARDENING - ПРОФЕССИОНАЛЬНАЯ НАСТРОЙКА${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Запустите от root: sudo bash $0${NC}"
    exit 1
fi

# ============================================================
# 1. КЛЮЧИ
# ============================================================

echo ""
echo -e "${YELLOW}📌 Откуда взять SSH ключи?${NC}"
echo ""
echo "  1) Скачать с GitHub (@mrpltrans)"
echo "  2) Вставить публичный ключ вручную"
echo "  3) Пропустить"
echo ""
read -p "$(echo -e ${CYAN}👉 Выберите [1-3]: ${NC})" KEY_CHOICE

case $KEY_CHOICE in
    1)
        echo ""
        echo -e "${YELLOW}📥 Скачиваем ключи...${NC}"
        mkdir -p /root/.ssh
        curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключи загружены${NC}"
        ;;
    2)
        echo ""
        echo -e "${YELLOW}🔑 Вставьте публичный SSH ключ:${NC}"
        read -r USER_KEY
        mkdir -p /root/.ssh
        echo "$USER_KEY" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключ сохранён${NC}"
        ;;
    3)
        echo ""
        echo -e "${YELLOW}⏭️ Пропускаем${NC}"
        ;;
esac

# Показываем ключи
if [ -s /root/.ssh/authorized_keys ]; then
    echo ""
    echo -e "${GREEN}🔐 Установленные ключи:${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
    cat /root/.ssh/authorized_keys
    echo -e "${CYAN}────────────────────────────────────────────────────────${NC}"
fi

# ============================================================
# 2. БЕЗОПАСНОСТЬ
# ============================================================

echo ""
echo -e "${YELLOW}🔒 Настраиваем безопасность SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

echo -e "${GREEN}✅ Вход по паролю ОТКЛЮЧЁН${NC}"
echo -e "${GREEN}✅ Вход только по ключам${NC}"

# ============================================================
# 3. ПОРТ
# ============================================================

CURRENT_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
[ -z "$CURRENT_PORT" ] && CURRENT_PORT=22

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📡 Текущий порт: ${GREEN}$CURRENT_PORT${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
read -p "$(echo -e ${CYAN}🔄 Сменить порт? (y/n): ${NC})" CHANGE_PORT

FINAL_PORT=$CURRENT_PORT

if [ "$CHANGE_PORT" = "y" ]; then
    while true; do
        echo ""
        read -p "$(echo -e ${YELLOW}🔢 Введите новый порт (1-65535): ${NC})" NEW_PORT
        
        if [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ] 2>/dev/null; then
            # Проверка занятости
            if ss -tln | grep -q ":$NEW_PORT "; then
                echo -e "${YELLOW}⚠️  Порт $NEW_PORT уже используется!${NC}"
                read -p "$(echo -e ${YELLOW}Всё равно использовать? (y/n): ${NC})" FORCE
                [ "$FORCE" != "y" ] && continue
            fi
            break
        else
            echo -e "${RED}❌ Ошибка! Порт от 1 до 65535${NC}"
        fi
    done
    
    # Открываем новый порт
    if command -v ufw &> /dev/null; then
        ufw allow $NEW_PORT/tcp 2>/dev/null
        echo -e "${GREEN}✅ Порт $NEW_PORT открыт${NC}"
    fi
    
    # Меняем порт
    if grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
    fi
    
    systemctl restart ssh
    echo -e "${GREEN}✅ SSH перезапущен${NC}"
    
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  ВАЖНО! НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Проверьте новое подключение в НОВОМ терминале:${NC}"
    echo -e "${CYAN}ssh -p $NEW_PORT root@$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}Новый порт работает? (y/n): ${NC})" VERIFY
    
    if [ "$VERIFY" = "y" ]; then
        # Закрываем старый порт
        if [ "$CURRENT_PORT" != "22" ]; then
            if command -v ufw &> /dev/null; then
                ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
                echo -e "${GREEN}✅ Порт $CURRENT_PORT закрыт${NC}"
            fi
        fi
        FINAL_PORT=$NEW_PORT
        echo -e "${GREEN}✅ Порт успешно изменён!${NC}"
    else
        # Откат
        echo -e "${YELLOW}Откатываем изменения...${NC}"
        sed -i "s/^Port .*/Port $CURRENT_PORT/" /etc/ssh/sshd_config
        if command -v ufw &> /dev/null; then
            ufw delete allow $NEW_PORT/tcp 2>/dev/null
        fi
        systemctl restart ssh
        echo -e "${GREEN}✅ Откат выполнен, порт $CURRENT_PORT восстановлен${NC}"
    fi
fi

# ============================================================
# ФИНАЛ
# ============================================================

IP_ADDRESS=$(hostname -I | awk '{print $1}')

clear
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              ✅ НАСТРОЙКА ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 ИТОГОВЫЕ НАСТРОЙКИ:${NC}"
echo -e "  • SSH порт: ${GREEN}$FINAL_PORT${NC}"
echo -e "  • Вход по паролю: ${RED}ОТКЛЮЧЁН${NC}"
echo -e "  • Вход по ключам: ${GREEN}ВКЛЮЧЁН${NC}"
echo ""
echo -e "${CYAN}🔑 УСТАНОВЛЕННЫЕ КЛЮЧИ:${NC}"
if [ -s /root/.ssh/authorized_keys ]; then
    cat /root/.ssh/authorized_keys
else
    echo "  Ключи не установлены"
fi
echo ""
echo -e "${CYAN}📝 ПОДКЛЮЧЕНИЕ:${NC}"
if [ "$FINAL_PORT" = "22" ]; then
    echo -e "  ssh root@$IP_ADDRESS"
else
    echo -e "  ssh -p $FINAL_PORT root@$IP_ADDRESS"
fi
echo ""
echo -e "${GREEN}✅ Сервер в безопасности!${NC}"
