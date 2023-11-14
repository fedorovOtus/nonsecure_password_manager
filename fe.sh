#!/bin/bash

# Установка Nginx
sudo apt update
sudo apt install -y nginx

# Запрос IP-адресов у пользователя
read -p "Введите первый IP-адрес сервера: " backend_ip1
read -p "Введите второй IP-адрес сервера: " backend_ip2

# Создание конфигурационного файла Nginx
cat <<EOF | sudo tee /etc/nginx/sites-enabled/default
upstream backend {
	server $backend_ip1:80;
	server $backend_ip2:80;
}

server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;

        include /etc/nginx/default.d/*.conf;

		location / {
			#try_files $uri $uri/ =404;
			proxy_pass http://backend/index.php;
			proxy_set_header Host \$host;
			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
			proxy_set_header X-Real-IP \$remote_addr;
		}

		location ~ \.php$ {
			include fastcgi_params;
			root /var/www/html;

			fastcgi_pass unix:/run/php/php7.4-fpm.sock;
			#fastcgi_pass 127.0.0.1:9000;
		}

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
}'
EOF

# Перезапуск Nginx для применения изменений
sudo systemctl restart nginx

echo "Настройка и установка завершены."


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


echo "Nginx успешно настроен для балансировки нагрузки между серверами: ${servers[@]}"
