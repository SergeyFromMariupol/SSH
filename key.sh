#!/bin/bash

# ============================================================
# SSH Hardening Script - Professional Edition (с самоуничтожением)
# Author: mrpltrans
# GitHub: https://github.com/mrpltrans/SSH
# ============================================================

set +H

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}        🚀 SSH HARDENING - МАКСИМАЛЬНАЯ БЕЗОПАСНОСТЬ${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Запустите от root: sudo bash $0${NC}"
    exit 1
fi

# ============================================================
# 1. ВЫБОР ИСТОЧНИКА КЛЮЧЕЙ
# ============================================================

echo -e "${YELLOW}📌 Откуда взять SSH ключи?${NC}"
echo ""
echo "  1) Скачать с GitHub (@mrpltrans)"
echo "  2) Вставить публичный ключ вручную"
echo "  3) Пропустить (оставить текущие ключи)"
echo ""
read -p "$(echo -e ${CYAN}👉 Выберите [1-3]: ${NC})" KEY_SOURCE

# Создаём папку .ssh
mkdir -p /root/.ssh

case $KEY_SOURCE in
    1)
        echo ""
        echo -e "${YELLOW}📥 Скачиваем ключи с GitHub...${NC}"
        if curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys; then
            chmod 700 /root/.ssh
            chmod 600 /root/.ssh/authorized_keys
            echo -e "${GREEN}✅ Ключи успешно загружены с GitHub${NC}"
        else
            echo -e "${RED}❌ Ошибка загрузки ключей${NC}"
        fi
        ;;
    2)
        echo ""
        echo -e "${YELLOW}🔑 Вставьте ваш публичный SSH ключ:${NC}"
        echo -e "${BLUE}Пример: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqGn4hzxZLqi/J2B8b+JRqGGuJeKP7vcEImKJDonCGN user@host${NC}"
        echo ""
        read -p "> " USER_KEY
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

# Показываем текущие ключи
if [ -s /root/.ssh/authorized_keys ]; then
    echo ""
    echo -e "${GREEN}🔐 Установленные ключи:${NC}"
    echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"
    cat /root/.ssh/authorized_keys
    echo -e "${WHITE}════════════════════════════════════════════════════════════${NC}"
fi

# ============================================================
# 2. НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================

echo ""
echo -e "${YELLOW}🔒 Настраиваем безопасность SSH...${NC}"

# Создаём бэкап
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# Отключаем пароли
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

echo -e "${GREEN}✅ Вход по паролю ОТКЛЮЧЁН${NC}"
echo -e "${GREEN}✅ Вход только по SSH ключам${NC}"
echo -e "${GREEN}✅ Root доступ только по ключам${NC}"

# ============================================================
# 3. СМЕНА ПОРТА (ОПЦИОНАЛЬНО)
# ============================================================

CURRENT_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
[ -z "$CURRENT_PORT" ] && CURRENT_PORT=22

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📡 Текущий SSH порт: ${GREEN}$CURRENT_PORT${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""
read -p "$(echo -e ${CYAN}🔄 Сменить порт? [y/N]: ${NC})" CHANGE_PORT

FINAL_PORT=$CURRENT_PORT

if [[ "$CHANGE_PORT" =~ ^[Yy]$ ]]; then
    while true; do
        echo ""
        read -p "$(echo -e ${YELLOW}🔢 Введите новый порт [1-65535]: ${NC})" NEW_PORT
        
        if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}❌ Ошибка! Введите число${NC}"
            continue
        fi
        
        if [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
            echo -e "${RED}❌ Ошибка! Порт должен быть от 1 до 65535${NC}"
            continue
        fi
        
        if ss -tln | grep -q ":$NEW_PORT "; then
            echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Порт $NEW_PORT уже используется другим сервисом!${NC}"
            ss -tln | grep ":$NEW_PORT "
            read -p "Всё равно использовать? (y/N): " FORCE
            if [[ ! "$FORCE" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        if [ "$NEW_PORT" = "$CURRENT_PORT" ]; then
            echo -e "${YELLOW}ℹ️  Порт $CURRENT_PORT уже используется, изменений не требуется${NC}"
            break
        fi
        
        break
    done
    
    if [ "$NEW_PORT" != "$CURRENT_PORT" ]; then
        if grep -q "^Port" /etc/ssh/sshd_config; then
            sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
        else
            echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
        fi
        
        if command -v ufw &> /dev/null; then
            echo ""
            echo -e "${YELLOW}🔥 Настраиваем фаерволл UFW...${NC}"
            ufw allow $NEW_PORT/tcp
            echo -e "${GREEN}✅ Порт $NEW_PORT открыт${NC}"
            
            if [ "$CURRENT_PORT" != "22" ]; then
                ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
                echo -e "${GREEN}✅ Порт $CURRENT_PORT закрыт${NC}"
            fi
            
            ufw reload 2>/dev/null
        else
            echo -e "${YELLOW}⚠️  UFW не установлен. Откройте порт $NEW_PORT вручную!${NC}"
        fi
        
        FINAL_PORT=$NEW_PORT
    fi
fi

# ============================================================
# 4. ПРОВЕРКА И ПЕРЕЗАПУСК
# ============================================================

echo ""
echo -e "${YELLOW}🔍 Проверяем конфигурацию SSH...${NC}"

if sshd -t 2>/dev/null; then
    echo -e "${GREEN}✅ Конфигурация корректна${NC}"
else
    echo -e "${RED}❌ Ошибка в конфигурации!${NC}"
    echo -e "${YELLOW}Восстанавливаем бэкап...${NC}"
    mv /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config 2>/dev/null
    systemctl restart ssh
    exit 1
fi

echo -e "${YELLOW}🔄 Перезапускаем SSH...${NC}"
systemctl restart ssh
echo -e "${GREEN}✅ SSH перезапущен${NC}"

# ============================================================
# 5. ФИНАЛЬНЫЙ ВЫВОД
# ============================================================

IP_ADDRESS=$(hostname -I | awk '{print $1}')

clear
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              ✅ НАСТРОЙКА УСПЕШНО ЗАВЕРШЕНА!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 ИТОГОВЫЕ НАСТРОЙКИ:${NC}"
echo -e "  • SSH порт: ${WHITE}$FINAL_PORT${NC}"
echo -e "  • Вход по паролю: ${RED}ОТКЛЮЧЁН${NC}"
echo -e "  • Вход по ключам: ${GREEN}ВКЛЮЧЁН${NC}"
echo -e "  • Root доступ: ${GREEN}только по ключам${NC}"
echo ""
echo -e "${CYAN}🔑 УСТАНОВЛЕННЫЕ КЛЮЧИ:${NC}"
if [ -s /root/.ssh/authorized_keys ]; then
    cat /root/.ssh/authorized_keys
else
    echo -e "${YELLOW}  Ключи не установлены${NC}"
fi
echo ""
echo -e "${CYAN}📝 ПОДКЛЮЧЕНИЕ К СЕРВЕРУ:${NC}"
if [ "$FINAL_PORT" = "22" ]; then
    echo -e "  ${WHITE}ssh root@$IP_ADDRESS${NC}"
else
    echo -e "  ${WHITE}ssh -p $FINAL_PORT root@$IP_ADDRESS${NC}"
fi
echo ""
echo -e "${RED}⚠️  КРИТИЧНО ВАЖНО:${NC}"
echo -e "  ${YELLOW}▶ НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
echo -e "  ${YELLOW}▶ Откройте НОВЫЙ терминал и проверьте подключение${NC}"
echo -e "  ${YELLOW}▶ Только после успешной проверки закрывайте эту сессию${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

# ============================================================
# 6. САМОУНИЧТОЖЕНИЕ
# ============================================================

SCRIPT_PATH="$(realpath "$0")"

echo ""
echo -e "${YELLOW}🗑️  Удаляем скрипт после выполнения...${NC}"

# Удаляем сам скрипт
rm -f "$SCRIPT_PATH" 2>/dev/null

# Удаляем пустую папку скрипта (если создавалась)
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
if [ -d "$SCRIPT_DIR" ] && [ "$SCRIPT_DIR" != "/root" ] && [ "$SCRIPT_DIR" != "/tmp" ]; then
    rmdir "$SCRIPT_DIR" 2>/dev/null
fi

echo -e "${GREEN}✅ Скрипт самоуничтожен${NC}"
echo ""
