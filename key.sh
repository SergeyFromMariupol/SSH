#!/bin/bash

# ============================================================
# SSH HARDENING SCRIPT - С ВЫБОРОМ СТРЕЛОЧКАМИ
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Функция выбора стрелочками
select_option() {
    local options=("${!1}")
    local selected=0
    
    while true; do
        echo ""
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "${CYAN}▶ ${options[$i]}${NC}"
            else
                echo "  ${options[$i]}"
            fi
        done
        
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ $key == '[A' ]]; then
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]}-1))
            elif [[ $key == '[B' ]]; then
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
            fi
        elif [[ $key == "" ]]; then
            return $selected
        fi
        
        # Очищаем строки меню
        for i in "${!options[@]}"; do
            echo -en "\033[1A\033[2K"
        done
    done
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
options=("Скачать с GitHub (@mrpltrans)" "Вставить публичный ключ вручную" "Пропустить (оставить текущие)")
select_option options[@]
KEY_CHOICE=$?

case $KEY_CHOICE in
    0)
        echo -e "\n${GREEN}✅ Выбрано: Скачать с GitHub${NC}"
        mkdir -p /root/.ssh
        curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys
        chmod 700 /root/.ssh
        chmod 600 /root/.ssh/authorized_keys
        echo -e "${GREEN}✅ Ключи загружены${NC}"
        ;;
    1)
        echo -e "\n${GREEN}✅ Выбрано: Вставить ключ вручную${NC}"
        mkdir -p /root/.ssh
        echo -e "${YELLOW}Вставьте публичный SSH ключ:${NC}"
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

# Показываем ключи если есть
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

echo -e "\n${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📡 Текущий SSH порт: ${GREEN}$CURRENT_PORT${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}🔄 Сменить порт?${NC}"
options=("Да, сменить порт" "Нет, оставить порт $CURRENT_PORT")
select_option options[@]
PORT_CHOICE=$?

if [ $PORT_CHOICE -eq 0 ]; then
    while true; do
        echo ""
        echo -n -e "${YELLOW}🔢 Введите новый порт (1-65535): ${NC}"
        read NEW_PORT
        
        if [ "$NEW_PORT" -ge 1 ] && [ "$NEW_PORT" -le 65535 ] 2>/dev/null; then
            # Проверка на занятость
            if ss -tln | grep -q ":$NEW_PORT "; then
                echo -e "${YELLOW}⚠️  Порт $NEW_PORT уже используется!${NC}"
                echo -e "${YELLOW}Хотите использовать его всё равно?${NC}"
                options=("Да, использовать" "Нет, выбрать другой")
                select_option options[@]
                FORCE_CHOICE=$?
                [ $FORCE_CHOICE -eq 1 ] && continue
            fi
            break
        else
            echo -e "${RED}❌ Ошибка! Порт должен быть от 1 до 65535${NC}"
        fi
    done
    
    # Открываем новый порт в UFW
    if command -v ufw &> /dev/null; then
        ufw allow $NEW_PORT/tcp 2>/dev/null
        echo -e "${GREEN}✅ Порт $NEW_PORT открыт в UFW${NC}"
    fi
    
    # Добавляем новый порт в конфиг
    if grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
    fi
    
    # Перезапускаем SSH
    systemctl restart ssh
    echo -e "${GREEN}✅ SSH перезапущен${NC}"
    
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  ВАЖНО! НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Проверьте новое подключение:${NC}"
    echo -e "${CYAN}ssh -p $NEW_PORT root@$(hostname -I | awk '{print $1}')${NC}"
    echo ""
    
    echo -e "${YELLOW}Новый порт работает?${NC}"
    options=("Да, всё работает! Закрыть старый порт" "Нет, откатить изменения")
    select_option options[@]
    VERIFY_CHOICE=$?
    
    if [ $VERIFY_CHOICE -eq 0 ]; then
        # Закрываем старый порт
        if [ "$CURRENT_PORT" != "22" ]; then
            if command -v ufw &> /dev/null; then
                ufw delete allow $CURRENT_PORT/tcp 2>/dev/null
                echo -e "${GREEN}✅ Порт $CURRENT_PORT закрыт${NC}"
            fi
        fi
        FINAL_PORT=$NEW_PORT
        echo -e "${GREEN}✅ Настройка порта завершена!${NC}"
    else
        # Откат
        echo -e "${YELLOW}Откатываем изменения...${NC}"
        if grep -q "^Port" /etc/ssh/sshd_config; then
            sed -i "s/^Port .*/Port $CURRENT_PORT/" /etc/ssh/sshd_config
        fi
        if command -v ufw &> /dev/null; then
            ufw delete allow $NEW_PORT/tcp 2>/dev/null
        fi
        systemctl restart ssh
        echo -e "${GREEN}✅ Откат выполнен, порт $CURRENT_PORT восстановлен${NC}"
        FINAL_PORT=$CURRENT_PORT
    fi
else
    FINAL_PORT=$CURRENT_PORT
    echo -e "${GREEN}✅ Порт оставлен без изменений: $FINAL_PORT${NC}"
fi

# ============================================================
# ФИНАЛЬНЫЙ ВЫВОД
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
echo -e "${GREEN}✅ Сервер в безопасности!${NC}"
echo ""
