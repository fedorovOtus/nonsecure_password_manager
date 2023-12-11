#!/bin/bash

# Проверяем, что у нас есть достаточно аргументов
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <remote_machine_ip1> <remote_machine_ip2> ..."
    exit 1
fi

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin





# Устанавливаем Grafana и Prometheus в Docker
docker run -d --name=grafana -p 3000:3000 grafana/grafana
docker run -d --name=prometheus -p 9090:9090 prom/prometheus

# Ждем некоторое время, чтобы убедиться, что Grafana и Prometheus успели запуститься
sleep 10

# Получаем IP-адреса удаленных машин из аргументов командной строки
remote_machines=("$@")

# Настраиваем источник данных Prometheus в Grafana
curl -X POST -H "Content-Type: application/json" \
-d '{"name":"prometheus", "type":"prometheus", "url":"http://localhost:9090", "access":"proxy"}' \
http://admin:admin@localhost:3000/api/datasources

# Настраиваем метрики для сбора от Node Exporter в Prometheus
for machine in "${remote_machines[@]}"; do
    # Настраиваем сбор метрик от Node Exporter
    curl -X POST -H "Content-Type: application/json" \
    -d '{"targets":["'"$machine"':9100"], "labels": {"alias": "'"$machine"'"}}' \
    http://localhost:9090/api/v1/targets

    # Создаем дашборд для машины
    dashboard_response=$(curl -s -X POST -H "Content-Type: application/json" \
    -d '{"dashboard": {"id":null,"title":"Server Metrics - '"$machine"'","tags":["server"],"timezone":"browser","schemaVersion":16,"version":0},"overwrite":false}' \
    http://admin:admin@localhost:3000/api/dashboards/import)

    # Извлекаем идентификатор созданного дашборда
    dashboard_id=$(echo $dashboard_response | jq -r '.id')

    # Настраиваем переменные для дашборда (IP-адрес удаленной машины)
    curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"remote_machine", "query":"'"$machine"'"}' \
    http://admin:admin@localhost:3000/api/dashboards/uid/$dashboard_id/settings

    # Импортируем дашборды для Node Exporter
    curl -X POST -H "Content-Type: application/json" \
    -d '{"dashboard": {"id":1860}, "overwrite": false, "inputs": [{"name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "prometheus"}]}' \
    http://admin:admin@localhost:3000/api/dashboards/import

    curl -X POST -H "Content-Type: application/json" \
    -d '{"dashboard": {"id":1861}, "overwrite": false, "inputs": [{"name": "DS_PROMETHEUS", "type": "datasource", "pluginId": "prometheus", "value": "prometheus"}]}' \
    http://admin:admin@localhost:3000/api/dashboards/import
done

echo "Grafana is set up and configured to collect and visualize metrics from Prometheus and Node Exporter on remote machines."
