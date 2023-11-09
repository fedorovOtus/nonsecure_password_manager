#!/bin/bash

# Проверяем, что у нас есть достаточно аргументов
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <remote_machine_ip1> <remote_machine_ip2> ..."
    exit 1
fi

# Устанавливаем Grafana в Docker
docker run -d --name=grafana -p 3000:3000 grafana/grafana

# Ждем некоторое время, чтобы убедиться, что Grafana успела запуститься
sleep 10

# Получаем IP-адреса удаленных машин из аргументов командной строки
remote_machines=("$@")

# Настраиваем источники данных (Prometheus) и дашборды в Grafana
for machine in "${remote_machines[@]}"; do
    # Настраиваем источник данных Prometheus
    curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"'"$machine"'", "type":"prometheus", "url":"http://'"$machine"':9090", "access":"proxy"}' \
    http://admin:admin@localhost:3000/api/datasources

    # Импортируем дашборды для Node Exporter
    curl -X POST -H "Content-Type: application/json" \
    -d '{"dashboard": {"id":1860}, "overwrite": false}' \
    http://admin:admin@localhost:3000/api/dashboards/import

    curl -X POST -H "Content-Type: application/json" \
    -d '{"dashboard": {"id":1861}, "overwrite": false}' \
    http://admin:admin@localhost:3000/api/dashboards/import

    # Настраиваем переменные для дашбордов (IP-адрес удаленной машины)
    curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"remote_machine", "query":"'"$machine"'"}' \
    http://admin:admin@localhost:3000/api/dashboards/uid/Node-Exporter-Server-Overview/settings

    curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"remote_machine", "query":"'"$machine"'"}' \
    http://admin:admin@localhost:3000/api/dashboards/uid/Node-Exporter-Disk-IO/settings
done

echo "Grafana is set up and configured to collect and visualize logs from Prometheus and Node Exporter on remote machines."
