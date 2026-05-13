#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - СТРЕЛОЧКИ РАБОТАЮТ КОРРЕКТНО
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Функция выбора стрелочками (исправленная)
select_option() {
    local options=("${!1}")
    local selected=0
    local len=${#options[@]}
    
    # Скрываем курсор
    printf "\e[?25l"
    
    while true; do
        # Очищаем предыдущее меню
        printf "\033[${len}A"  # Поднимаемся на количество строк
        for i in $(seq 1 $len); do
            printf "\033[2K"   # Очищаем строку
        done
        printf "\033[${len}A"  # Снова поднимаемся
        
        # Рисуем меню заново
        echo ""
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "${CYAN}▶ ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        
        # Читаем клавишу
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            if [[ $key2 == '[A' ]]; then
                ((selected--))
                [ $selected -lt 0 ] && selected=$((len-1))
            elif [[ $key2 == '[B' ]]; then
                ((selected++))
                [ $selected -ge $len ] && selected=0
            fi
        elif [[ $key == "" ]]; then
            # Enter нажат
            printf "\e[?25h"  # Показываем курсор
            return $selected
        fi
    done
}

# Обычный ввод с подсказкой
prompt() {
    echo -n -e "${YELLOW}$1${NC}"
    read "$2"
}

clear
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}        🚀 SSH HARDENING - ПРОФЕССИОНАЛЬНАЯ НАСТРОЙКА${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Запустите от root: sudo bash $0${NC}"
    exit 1
fi

# ============================================================
# 1. ВЫБОР ИСТОЧНИКА КЛЮЧЕЙ
# ============================================================

echo -e "\n${YELLOW}📌 Откуда взять SSH ключи?${NC}"
options=("Скачать с GitHub (@mrpltrans)" "Вставить публичный ключ вручную" "Пропустить")
select_option options[@]
KEY_CHOICE=$?

case $KEY_CHOICE in
    0)
        echo -e "\n${GREEN}✅ Скачиваем ключи с GitHub...${NC}"
        mkdir -p /root/.ssh
        curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключи загружены${NC}"
        ;;
    1)
        echo -e "\n${GREEN}✅ Вставьте публичный SSH ключ:${NC}"
        mkdir -p /root/.ssh
        read -r USER_KEY
        echo "$USER_KEY" > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключ сохранён${NC}"
        ;;
    2)
        echo -e "\n${YELLOW}⏭️ Пропускаем установку ключей${NC}"
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
# 2. НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================

echo -e "\n${YELLOW}🔒 Настраиваем безопасность SSH...${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

echo -e "${GREEN}✅ Вход по паролю ОТКЛЮЧЁН${NC}"
echo -e "${GREEN}✅ Вход только по SSH ключам${NC}"

# ============================================================
# 3. СМЕНА ПОРТА
# ============================================================

CURRENT_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
[ -z "$CURRENT_PORT" ] && CURRENT_PORT=22

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📡 Текущий SSH порт: ${GREEN}$CURRENT_PORT${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}🔄 Сменить порт?${NC}"
options=("Да, сменить порт" "Нет, оставить порт $CURRENT_PORT")
select_option options[@]
PORT_CHOICE=$?

FINAL_PORT=$CURRENT_PORT

if [ $PORT_CHOICE -eq 0 ]; then
    while true; do
        echo ""
        prompt "🔢 Введите новый порт (1-65535): " NEW_PORT
        
        if [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ] 2>/dev/null; then
            # Проверка на занятость
            if ss -tln | grep -q ":$NEW_PORT "; then
                echo -e "${YELLOW}⚠️  Порт $NEW_PORT уже используется!${NC}"
                echo -e "${YELLOW}Использовать его всё равно?${NC}"
                options=("Да" "Нет, другой")
                select_option options[@]
                [ $? -eq 1 ] && continue
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
    echo -e "${RED}⚠️  НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Проверьте: ssh -p $NEW_PORT root@$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    
    echo -e "${YELLOW}Новый порт работает?${NC}"
    options=("Да, закрыть старый" "Нет, откатить")
    select_option options[@]
    
    if [ $? -eq 0 ]; then
        if command -v ufw &> /dev/null; then
            ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
            echo -e "${GREEN}✅ Порт $CURRENT_PORT закрыт${NC}"
        fi
        FINAL_PORT=$NEW_PORT
        echo -e "${GREEN}✅ Готово!${NC}"
    else
        sed -i "s/^Port .*/Port $CURRENT_PORT/" /etc/ssh/sshd_config
        command -v ufw &> /dev/null && ufw delete allow $NEW_PORT/tcp 2>/dev/null
        systemctl restart ssh
        echo -e "${GREEN}✅ Откат, порт $CURRENT_PORT${NC}"
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
echo -e "${CYAN}📋 НАСТРОЙКИ:${NC}"
echo -e "  • Порт: ${WHITE}$FINAL_PORT${NC}"
echo -e "  • Пароли: ${RED}ОТКЛЮЧЕНЫ${NC}"
echo -e "  • Ключи: ${GREEN}ВКЛЮЧЕНЫ${NC}"
echo ""
echo -e "${CYAN}📝 ПОДКЛЮЧЕНИЕ:${NC}"
if [ "$FINAL_PORT" = "22" ]; then
    echo -e "  ${WHITE}ssh root@$IP_ADDRESS${NC}"
else
    echo -e "  ${WHITE}ssh -p $FINAL_PORT root@$IP_ADDRESS${NC}"
fi
echo ""
