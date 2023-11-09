#!/bin/bash

# Установка MySQL Server 8.0 и передача пароля от root во все команды
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server-8.0

# Настройка конфигурационных файлов под режим slave
sudo echo "[mysqld]" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "server-id=2" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "log-bin=mysql-bin" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "relay-log=mysql-relay-bin" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "log-slave-updates=1" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/bind-address/ c\bind-address = 0.0.0.0' /etc/mysql/mysql.conf.d/mysqld.cnf # Заменяем bind-address

# Перезапуск MySQL
sudo service mysql restart

# Пароль для пользователя root
read -p $'\e[33mВведите пароль для пользователя \'root\': \e[0m' root_password

# Установка пароля для root и передача пароля в команды
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$root_password';"

# Подключение к мастер серверу для настройки репликации
read -p $'\e[33mВведите IP-адрес мастер сервера: \e[0m' master_ip
read -p $'\e[33mВведите пароль для пользователя \'repl\' на мастер сервере: \e[0m' repl_password
read -p $'\e[33mВведите master_log_file: \e[0m' master_log_file
read -p $'\e[33mВведите master_log_pos: \e[0m' master_log_pos

# Настройка репликации
sudo mysql -uroot -p"$root_password" -e "CHANGE MASTER TO MASTER_HOST='$master_ip', MASTER_USER='repl', MASTER_PASSWORD='$repl_password', MASTER_LOG_FILE='$master_log_file', MASTER_LOG_POS=$master_log_pos, GET_MASTER_PUBLIC_KEY=1;"
sudo mysql -uroot -p"$root_password" -e "START SLAVE;"

# Установка Prometheus
echo "Установка Prometheus..."
wget https://github.com/prometheus/prometheus/releases/download/v2.30.3/prometheus-2.30.3.linux-amd64.tar.gz
tar xvfz prometheus-2.30.3.linux-amd64.tar.gz
cd prometheus-2.30.3.linux-amd64
./prometheus --version
./prometheus &

# Установка Node Exporter
echo "Установка Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.2.2/node_exporter-1.2.2.linux-amd64.tar.gz
tar xvfz node_exporter-1.2.2.linux-amd64.tar.gz
cd node_exporter-1.2.2.linux-amd64
./node_exporter --version
./node_exporter &

echo "Prometheus и Node Exporter установлены и запущены."


# Вывести slave status
echo -e "\e[32mСтатус slave сервера:\e[0m"
sudo mysql -uroot -p"$root_password" -e "SHOW SLAVE STATUS\G"

echo -e "\e[32mНастройка завершена.\e[0m"
