#!/bin/bash

# Установка Nginx
sudo apt update
sudo apt install -y nginx

# Запрос IP-адресов у пользователя
read -p "Введите первый IP-адрес сервера: " backend_ip1
read -p "Введите второй IP-адрес сервера: " backend_ip2

# Создание конфигурационного файла Nginx
sudo tee /etc/nginx/sites-available/default >/dev/null <<EOF
server {
    listen 80;

    location / {
        # Балансировка между двумя серверами
        proxy_pass http://\$backend_ip1\$request_uri;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /index.php {
        # Балансировка между двумя серверами
        proxy_pass http://\$backend_ip2\$request_uri;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Перезапуск Nginx для применения изменений
sudo systemctl restart nginx

echo "Настройка и установка завершены."
