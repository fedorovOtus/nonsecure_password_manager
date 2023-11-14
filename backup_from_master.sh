#!/bin/bash

# Настройки базы данных
DB_HOST="slave_host" # Хост slave-сервера
DB_USER="username" # Пользователь базы данных
DB_PASSWORD="password" # Пароль пользователя базы данных

# Директория для хранения бэкапов
BACKUP_DIR="/path/to/backup_directory"

# Создаем директорию для бэкапов, если она не существует
mkdir -p "${BACKUP_DIR}"

# Останавливаем репликацию на slave-сервере
mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "STOP SLAVE;"

# Получаем список всех баз данных, исключая системные базы данных
DATABASES=$(mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|mysql|performance_schema|sys)")

# Создаем бэкап для каждой таблицы в каждой базе данных
for db in ${DATABASES}; do
TABLES=$(mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -D "${db}" -e "SHOW TABLES;" | grep -vE "(Tables_in_)")

for table in ${TABLES}; do
BACKUP_FILE="${BACKUP_DIR}/${db}_${table}_backup_$(date +%Y%m%d_%H%M%S).sql"
mysqldump -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" \
--single-transaction --routines --triggers --events \
--master-data=2 "${db}" "${table}" --binlog="${BACKUP_FILE}"

# Проверяем успешность выполнения mysqldump
if [ $? -eq 0 ]; then
echo "Backup for ${db}.${table} sucsessful: ${BACKUP_FILE}"
else
echo "Something went wrong for ${db}.${table}."
fi
done
done

# Возобновляем репликацию на slave-сервере
mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "START SLAVE;"
