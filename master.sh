#!/bin/bash

# Установка MySQL Server 8.0 и передача пароля от root во все команды
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server-8.0

# Настройка конфигурационных файлов под режим мастера
sudo echo "[mysqld]" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "server-id=1" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo echo "log-bin=mysql-bin" >> /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/bind-address/ c\bind-address = 0.0.0.0' /etc/mysql/mysql.conf.d/mysqld.cnf # Заменяем bind-address

# Перезапуск MySQL
sudo service mysql restart

# Пароль для пользователя root
read -p $'\e[33mВведите пароль для пользователя \'root\': \e[0m' root_password

# Установка пароля для root и передача пароля в команды
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$root_password';"

# Создание пользователя be и установка пароля и хоста
read -p $'\e[33mВведите пароль для пользователя \'be\': \e[0m' be_password
read -p $'\e[33mВведите хост для пользователя 1 \'be\' (например, localhost): \e[0m' be_host1
read -p $'\e[33mВведите хост для пользователя 2 \'be\' (например, localhost): \e[0m' be_host2
sudo mysql -uroot -p"$root_password" -e "CREATE USER 'be'@'$be_host1' IDENTIFIED WITH 'caching_sha2_password' BY '$be_password';"
sudo mysql -uroot -p"$root_password" -e "CREATE USER 'be'@'$be_host2' IDENTIFIED WITH 'caching_sha2_password' BY '$be_password';"
echo -e "\e[32mПользователь 'be' успешно добавлен.\e[0m"

# Создание пользователя repl и установка пароля и хоста
read -p $'\e[33mВведите пароль для пользователя \'repl\': \e[0m' repl_password
sudo mysql -uroot -p"$root_password" -e "CREATE USER 'repl'@'%' IDENTIFIED WITH 'caching_sha2_password' BY '$repl_password';"
sudo mysql -uroot -p"$root_password" -e "ALTER USER 'repl'@'%' IDENTIFIED WITH 'caching_sha2_password' BY '$repl_password';"
echo -e "\e[32mПользователь 'repl' успешно добавлен.\e[0m"

# Дать права пользователю repl на полную репликацию
sudo mysql -uroot -p"$root_password" -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"

# Создание базы данных passwords и таблиц logins и passwords
sudo mysql -uroot -p"$root_password" -e "CREATE DATABASE passwords;"
sudo mysql -uroot -p"$root_password" -e "USE passwords; CREATE TABLE passwords (id INT AUTO_INCREMENT PRIMARY KEY,login VARCHAR(255), password VARCHAR(255));"
sudo mysql -uroot -p"$root_password" -e "USE passwords; insert into passwords (id, login, password) values (1, 2, 3);"

# Выдать права на чтение для таблицы logins и права на чтение и запись для таблицы passwords для пользователя be
sudo mysql -uroot -p"$root_password" -e "GRANT SELECT, INSERT ON passwords.passwords TO 'be'@'$be_host1';"
sudo mysql -uroot -p"$root_password" -e "GRANT SELECT, INSERT ON passwords.passwords TO 'be'@'$be_host2';"

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


# Вывести master status
echo -e "\e[32mСОХРАНИТЕ ЭТИ ДАННЫЕ ДЛЯ НАСТРОЙКИ SLAVE\e[0m"
sudo mysql -uroot -p"$root_password" -e "SHOW MASTER STATUS;"

# Вывести список пользователей MySQL
echo -e "\e[32mСписок пользователей MySQL:\e[0m"
sudo mysql -uroot -p"$root_password" -e "SELECT user, host FROM mysql.user;"

echo -e "\e[32mНастройка завершена.\e[0m"


