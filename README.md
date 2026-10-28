# OpenConnect VPN (ocserv) Monitoring for Zabbix 7

Шаблон и скрипты для мониторинга сервера OpenConnect VPN (ocserv) с помощью Zabbix 7 и Zabbix Agent 2.

##  Что мониторится

**Общие метрики сервера:**
- Активные и общие сессии
- Ошибки аутентификации
- Количество IP в бан-листе
- Время запуска сервиса (Uptime) и проверка на зависание/перезапуск
- Общий трафик (RX/TX) в байтах

 **Метрики пользователей (Low-Level Discovery):**
- Статус (Online/Offline) на основе списка `ocpasswd`
- Трафик конкретного пользователя (RX/TX)
- Remote IP
- Device (User-Agent)
- Hostname
- Время подключения

**Метрики забаненных IP (Low-Level Discovery):**
- Список забаненных IP
- Триггер на бан с указанием конкретного IP

##  Установка

### 1. Установка зависимостей
На сервере с ocserv должны быть установлены `jq` и `zabbix-agent2`:
```bash
sudo apt update
sudo apt install -y jq zabbix-agent2
```
### 2. Настройка прав доступа
Скрипт запускается от имени пользователя zabbix. Дайте ему права на чтение статистики ocserv и файла с паролями:

```bash
# Добавляем zabbix в группу ocserv (для доступа к сокету)
sudo usermod -aG ocserv zabbix

# Создаем правило sudoers для occtl (чтобы не было Permission denied)
echo "zabbix ALL=(ALL) NOPASSWD: /usr/bin/occtl" | sudo tee /etc/sudoers.d/zabbix-ocserv
sudo chmod 440 /etc/sudoers.d/zabbix-ocserv
```
### 3. Установка скрипта
```bash
sudo mkdir -p /etc/zabbix/scripts/
sudo cp scripts/ocserv_stats.sh /etc/zabbix/scripts/ocserv_stats.sh
sudo chmod +x /etc/zabbix/scripts/ocserv_stats.sh
```

### 4. Настройка Zabbix Agent 2
Скопируйте конфиг агента:

```bash
sudo cp zabbix_agent/ocserv.conf /etc/zabbix/zabbix_agent2.d/ocserv.conf
sudo systemctl restart zabbix-agent2
```

### 5. Импорт шаблона в Zabbix
В веб-интерфейсе Zabbix перейдите в Data collection -> Templates -> Import.

Выберите файл zabbix_template/template_openconnect_vpn.yaml.

Привяжите шаблон OpenConnect VPN (ocserv) к вашему хосту.

### Проверка работы
На сервере с агентом:

```bash
sudo -u zabbix /etc/zabbix/scripts/ocserv_stats.sh active_sessions
sudo -u zabbix /etc/zabbix/scripts/ocserv_stats.sh user_list
```

С сервера Zabbix:

```bash
zabbix_get -s <OCSERV_IP> -k ocserv.ban.discovery
zabbix_get -s <OCSERV_IP> -k 'ocserv.user.status[<USERNAME>]'
```

###  Troubleshooting (Решение проблем)

Ошибка Permission denied для occtl: Пользователь zabbix не входит в группу ocserv или нет правила в sudoers.
Ошибка Unknown metric: Конфиг агента лежит не в той папке. В Agent 2 это /etc/zabbix/zabbix_agent2.d/.

### Примечания

Шаблон использует Value Mapping для отображения статуса пользователя (1 = Online, 0 = Offline).

Для корректной работы LLD пользователей в конфиге ocserv должен быть включен use-occtl = true.

Скрипт собирает список всех пользователей из файла /etc/ocserv/ocpasswd. Убедитесь, что у пользователя zabbix есть права на чтение этого файла 
(обычно достаточно добавить его в группу ocserv).


### Лицензия
Этот проект распространяется под лицензией MIT. Подробности в файле LICENSE.

