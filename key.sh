#!/bin/bash

# ============================================================
# SSH Hardening Script - Безопасная настройка SSH сервера
# Версия: 2.1 (исправленная)
# Автор: mrpltrans
# GitHub: https://github.com/mrpltrans/ssh-hardening
# ============================================================

set +H

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔐 $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Проверка root
if [ "$EUID" -ne 0 ]; then 
    print_error "Скрипт должен запускаться от root"
    exit 1
fi

# Приветствие
clear
echo -e "${PURPLE}"
echo "   ███████╗███████╗██╗  ██╗    ██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███╗   ██╗██╗███╗   ██╗ ██████╗ "
echo "   ██╔════╝██╔════╝██║  ██║    ██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║██║████╗  ██║██╔════╝ "
echo "   ███████╗███████╗███████║    ███████║███████║██████╔╝██████╔╝█████╗  ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗"
echo "   ╚════██║╚════██║██╔══██║    ██╔══██║██╔══██║██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║██║██║╚██╗██║██║   ██║"
echo "   ███████║███████║██║  ██║    ██║  ██║██║  ██║██║  ██║██║  ██║███████╗██║ ╚████║██║██║ ╚████║╚██████╔╝"
echo "   ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ "
echo -e "${NC}"
echo -e "${CYAN}             SSH Hardening Script v2.1 - Безопасность за 5 минут${NC}"
echo ""

# Текущий порт
CURRENT_PORT=$(grep -E "^Port" /etc/ssh/sshd_config | awk '{print $2}')
[ -z "$CURRENT_PORT" ] && CURRENT_PORT=22

print_header "ТЕКУЩАЯ КОНФИГУРАЦИЯ"
echo -e "   ${CYAN}📡 SSH порт:${NC} $CURRENT_PORT"
echo -e "   ${CYAN}🌐 IP адрес:${NC} $(hostname -I | awk '{print $1}')"
echo -e "   ${CYAN}🖥️  Хост:${NC} $(hostname)"
echo ""

# Меню
print_header "ВЫБЕРИТЕ ДЕЙСТВИЕ"
echo ""
echo -e "   ${GREEN}1)${NC} 🚀 Полная настройка (ключи + безопасность) - порт НЕ трогать"
echo -e "   ${GREEN}2)${NC} 🔄 Полная настройка + СМЕНИТЬ порт"
echo -e "   ${GREEN}3)${NC} 🔙 Оставить только ключи, вернуть порт 22"
echo -e "   ${GREEN}4)${NC} 📊 Только показать текущие настройки (ничего не менять)"
echo -e "   ${GREEN}5)${NC} ❌ Выход"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
read -p "$(echo -e ${YELLOW}👉 Введите номер действия [1-5]:${NC} )" ACTION

case $ACTION in
    4)
        print_header "ТЕКУЩИЕ НАСТРОЙКИ SSH"
        grep -E "^(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication)" /etc/ssh/sshd_config | grep -v "^#" || echo "Стандартные настройки"
        exit 0
        ;;
    5)
        print_info "Выход"
        exit 0
        ;;
esac

# ============================================================
# ОСНОВНАЯ НАСТРОЙКА
# ============================================================

print_header "НАСТРОЙКА SSH КЛЮЧЕЙ"

print_info "Создаём папку .ssh..."
mkdir -p /root/.ssh
print_success "Папка создана"

print_info "Скачиваем ключи с GitHub..."
if curl -s https://github.com/mrpltrans.keys > /root/.ssh/authorized_keys; then
    print_success "Ключи успешно загружены"
else
    print_error "Не удалось загрузить ключи"
    exit 1
fi

print_info "Устанавливаем права доступа..."
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
print_success "Права установлены"

echo ""
print_info "Добавленные ключи:"
echo -e "${GREEN}"
cat /root/.ssh/authorized_keys
echo -e "${NC}"

print_info "Создаём бэкап конфигурации..."
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
cp /etc/ssh/sshd_config "$BACKUP_FILE"
print_success "Бэкап создан: $BACKUP_FILE"

# ============================================================
# НАСТРОЙКА БЕЗОПАСНОСТИ
# ============================================================

print_header "НАСТРОЙКА ПАРАМЕТРОВ БЕЗОПАСНОСТИ"

# Функция для безопасной замены параметров
set_ssh_param() {
    local param=$1
    local value=$2
    if grep -q "^$param" /etc/ssh/sshd_config; then
        sed -i "s/^$param.*/$param $value/" /etc/ssh/sshd_config
    elif grep -q "^#$param" /etc/ssh/sshd_config; then
        sed -i "s/^#$param.*/$param $value/" /etc/ssh/sshd_config
    else
        echo "$param $value" >> /etc/ssh/sshd_config
    fi
}

set_ssh_param "PasswordAuthentication" "no"
print_success "PasswordAuthentication: NO"

set_ssh_param "PubkeyAuthentication" "yes"
print_success "PubkeyAuthentication: YES"

set_ssh_param "PermitRootLogin" "prohibit-password"
print_success "PermitRootLogin: prohibit-password"

set_ssh_param "ChallengeResponseAuthentication" "no"
print_success "ChallengeResponseAuthentication: NO"

set_ssh_param "PermitEmptyPasswords" "no"
print_success "PermitEmptyPasswords: NO"

# ============================================================
# НАСТРОЙКА ПОРТА
# ============================================================

FINAL_PORT=$CURRENT_PORT

if [ "$ACTION" = "2" ]; then
    print_header "СМЕНА SSH ПОРТА"
    
    while true; do
        echo ""
        read -p "Введите новый порт [1024-65535] (2222, 4444, 55555): " NEW_PORT
        
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [ "$NEW_PORT" -ge 1024 ] && [ "$NEW_PORT" -le 65535 ]; then
            break
        else
            print_error "Порт должен быть от 1024 до 65535"
        fi
    done
    
    print_info "Меняем порт с $CURRENT_PORT на $NEW_PORT..."
    set_ssh_param "Port" "$NEW_PORT"
    FINAL_PORT=$NEW_PORT
    
    if command -v ufw &> /dev/null; then
        print_info "Настраиваем UFW..."
        ufw allow "$NEW_PORT"/tcp 2>/dev/null
        ufw delete allow "$CURRENT_PORT"/tcp 2>/dev/null
        ufw reload 2>/dev/null
        print_success "Порт $NEW_PORT открыт, порт $CURRENT_PORT закрыт"
    else
        print_warning "UFW не установлен. Откройте порт $NEW_PORT вручную"
    fi
fi

if [ "$ACTION" = "3" ]; then
    print_header "ВОЗВРАТ НА ПОРТ 22"
    print_info "Меняем порт с $CURRENT_PORT на 22..."
    set_ssh_param "Port" "22"
    FINAL_PORT=22
    
    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp 2>/dev/null
        ufw delete allow "$CURRENT_PORT"/tcp 2>/dev/null
        ufw reload 2>/dev/null
        print_success "Порт 22 открыт"
    fi
fi

# ============================================================
# ПРОВЕРКА И ПЕРЕЗАПУСК
# ============================================================

print_header "ПРОВЕРКА И ПРИМЕНЕНИЕ"

print_info "Проверяем конфигурацию SSH..."
if sshd -t 2>/dev/null; then
    print_success "Конфигурация корректна"
else
    print_error "Ошибка в конфигурации!"
    print_info "Восстанавливаем бэкап..."
    mv "$BACKUP_FILE" /etc/ssh/sshd_config
    systemctl restart ssh
    exit 1
fi

print_info "Перезапускаем SSH..."
systemctl restart ssh
print_success "SSH перезапущен"

# ============================================================
# ФИНАЛЬНЫЙ ВЫВОД
# ============================================================

IP_ADDRESS=$(hostname -I | awk '{print $1}')

clear
print_header "НАСТРОЙКА ЗАВЕРШЕНА УСПЕШНО!"

echo -e "${GREEN}"
echo "   ╔══════════════════════════════════════════════════════════════╗"
echo "   ║                    ✅ ВСЁ ГОТОВО!                            ║"
echo "   ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}📋 ИТОГОВЫЕ НАСТРОЙКИ:${NC}"
echo -e "   • ${GREEN}SSH порт:${NC} $FINAL_PORT"
echo -e "   • ${GREEN}Вход по паролю:${NC} ${RED}ОТКЛЮЧЁН${NC}"
echo -e "   • ${GREEN}Вход по ключам:${NC} ${GREEN}ВКЛЮЧЁН${NC}"
echo -e "   • ${GREEN}Root доступ:${NC} только по ключам"
echo ""

echo -e "${CYAN}🔑 УСТАНОВЛЕННЫЕ КЛЮЧИ:${NC}"
echo -e "${GREEN}"
cat /root/.ssh/authorized_keys
echo -e "${NC}"

echo -e "${CYAN}📝 ПОДКЛЮЧЕНИЕ:${NC}"
if [ "$FINAL_PORT" = "22" ]; then
    echo -e "   ${YELLOW}ssh root@$IP_ADDRESS${NC}"
else
    echo -e "   ${YELLOW}ssh -p $FINAL_PORT root@$IP_ADDRESS${NC}"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  КРИТИЧНО ВАЖНО:${NC}"
echo -e "   ${YELLOW}▶ НЕ ЗАКРЫВАЙТЕ ЭТУ СЕССИЮ!${NC}"
echo -e "   ${YELLOW}▶ Откройте НОВЫЙ терминал и проверьте подключение${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
