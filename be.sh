#!/bin/bash

# Установка Apache и PHP
sudo apt-get update
sudo apt-get install -y apache2 php libapache2-mod-php php-mysql

# Создание конфигурационного файла для Apache
cat <<EOL | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined

    <Directory /var/www/html>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

   
</VirtualHost>
EOL

# Перезапуск Apache
sudo systemctl restart apache2

# Создание конфигурационного файла для PHP
cat <<EOL | sudo tee /etc/php/7.4/apache2/php.ini
; Настройки для PHP
...
EOL

# Запрос данных для подключения к базе данных
read -p "Введите хост базы данных: " db_host
read -p "Введите имя пользователя MySQL: " db_user
read -s -p "Введите пароль MySQL: " db_password

# Создание файла с данными для подключения к базе данных
cat <<EOL | sudo tee /var/www/html/db_config.php
<?php
\$db_host = '$db_host';
\$db_user = 'be';
\$db_password = '$db_password';
\$db_name = 'passwords'; # Имя базы данных
?>
EOL

# Создание файла для вывода данных в веб-браузере
cat <<EOL | sudo tee /var/www/html/index.php
<?php
require_once 'db_config.php';

\$conn = new mysqli(\$db_host, \$db_user, \$db_password, \$db_name);
if (\$conn->connect_error) {
    die("Connection failed: " . \$conn->connect_error);
}

\$sql = "SELECT id, login, password FROM passwords";
\$result = \$conn->query(\$sql);

if (\$result->num_rows > 0) {
    echo "<table border='1'><tr><th>ID</th><th>Login</th><th>Password</th></tr>";
    while(\$row = \$result->fetch_assoc()) {
        echo "<tr><td>" . \$row["id"]. "</td><td>" . \$row["login"]. "</td><td>" . \$row["password"]. "</td></tr>";
    }
    echo "</table>";
} else {
    echo "0 results found";
}

\$conn->close();
?>
EOL

# Установка прав на файлы
sudo chown www-data:www-data /var/www/html/db_config.php
sudo chown www-data:www-data /var/www/html/index.php

# Перезапуск Apache для применения изменений
sudo systemctl restart apache2

# Установка утилит мониторинга
apt install -y htop iotop iftop atop iptraf-ng nmon

# Скачиваем Prometheus и Node Exporter
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.46.0/prometheus-2.46.0.linux-amd64.tar.gz
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz

# Распаковка архивов 
tar xzvf node_exporter-*.t*gz
tar xzvf prometheus-*.t*gz

# Добавляем пользователей
useradd --no-create-home --shell /usr/sbin/nologin prometheus
useradd --no-create-home --shell /bin/false node_exporter

# Устанавливаем Node Exporter
cp node_exporter-*.linux-amd64/node_exporter /usr/local/bin
chown node_exporter: /usr/local/bin/node_exporter

# Создаем службу Node Exporter
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Устанавливаем Prometheus
mkdir -p /etc/prometheus /var/lib/prometheus
cp -vi prometheus-*.linux-amd64/prom{etheus,tool} /usr/local/bin
cp -rvi prometheus-*.linux-amd64/{console{_libraries,s},prometheus.yml} /etc/prometheus/
chown -Rv prometheus: /usr/local/bin/prom{etheus,tool} /etc/prometheus/ /var/lib/prometheus/

# Создаем службу Prometheus
cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

# Конфиг Prometheus
cat > /etc/prometheus/prometheus.yml <<EOF
# my global config
global:
  scrape_interval:     15s
  evaluation_interval: 15s

# Alertmanager configuration
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
  
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9100']
EOF

# Запускаем Prometheus
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

echo "Prometheus и Node Exporter установлены и запущены."


echo "Apache и PHP успешно установлены. Данные для подключения к базе данных сохранены в /var/www/html/db_config.php."
