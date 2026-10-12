#!/usr/bin/env bash
# Bài 4: Custom Bridge Network & Named Volume bằng Docker CLI
set -euo pipefail

NETWORK="app-net"
VOLUME="db-data"
DB_CONTAINER="db-server"
APP_CONTAINER="app-container"

DB_NAME="appdb"
DB_USER="appuser"
DB_PASS="apppass"

# Image backend: truyền BACKEND_IMAGE=<image-api-của-bạn> để dùng API thật.
# Mặc định dùng alpine (có sẵn ping) chạy nền để demo DNS nội bộ.
BACKEND_IMAGE="${BACKEND_IMAGE:-}"

start_db() {
  docker run -d \
    --name "$DB_CONTAINER" \
    --network "$NETWORK" \
    -v "$VOLUME":/var/lib/postgresql/data \
    -e POSTGRES_DB="$DB_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASS" \
    postgres:15-alpine

  echo ">> Chờ PostgreSQL sẵn sàng..."
  until docker exec "$DB_CONTAINER" pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; do
    sleep 1
  done
}

psql_db() {
  docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "$1"
}

echo "=== 0. Dọn môi trường cũ ==="
docker rm -f "$APP_CONTAINER" "$DB_CONTAINER" >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true
docker volume rm "$VOLUME" >/dev/null 2>&1 || true

echo "=== 1. Tạo Custom Bridge Network: $NETWORK ==="
docker network create --driver bridge "$NETWORK"

echo "=== 2. Tạo Named Volume: $VOLUME ==="
docker volume create "$VOLUME"

echo "=== 3. Chạy Database Container: $DB_CONTAINER ==="
start_db

echo "=== 4. Chạy Backend Container: $APP_CONTAINER ==="
BACKEND_ENV=(
  -e SPRING_DATASOURCE_URL="jdbc:postgresql://${DB_CONTAINER}:5432/${DB_NAME}"
  -e SPRING_DATASOURCE_USERNAME="$DB_USER"
  -e SPRING_DATASOURCE_PASSWORD="$DB_PASS"
  -e DB_HOST="$DB_CONTAINER"
  -e DB_PORT=5432
  -e DB_NAME="$DB_NAME"
  -e DB_USER="$DB_USER"
  -e DB_PASSWORD="$DB_PASS"
)
if [ -n "$BACKEND_IMAGE" ]; then
  docker run -d --name "$APP_CONTAINER" --network "$NETWORK" "${BACKEND_ENV[@]}" -p 8080:8080 "$BACKEND_IMAGE"
else
  docker run -d --name "$APP_CONTAINER" --network "$NETWORK" "${BACKEND_ENV[@]}" alpine:3.19 sleep infinity
fi

echo "=== 5. Kiểm tra DNS nội bộ: ping db-server ==="
docker exec "$APP_CONTAINER" ping -c 2 "$DB_CONTAINER"

echo "=== 6. Test Data Persistence ==="
echo "-- 6.1 Thêm dữ liệu"
psql_db "CREATE TABLE IF NOT EXISTS students (id SERIAL PRIMARY KEY, name VARCHAR(100));"
psql_db "INSERT INTO students (name) VALUES ('Poh'), ('Docker');"
psql_db "SELECT * FROM students;"

echo "-- 6.2 Xóa cứng container DB"
docker rm -f "$DB_CONTAINER"

echo "-- 6.3 Tạo lại container DB mới, gắn cùng volume $VOLUME"
start_db

echo "-- 6.4 Xác minh dữ liệu còn nguyên"
psql_db "SELECT * FROM students;"

echo "=== Kiểm tra cuối ==="
docker network ls | grep "$NETWORK"
docker volume ls | grep "$VOLUME"
docker network inspect "$NETWORK"
echo "HOÀN TẤT: dữ liệu được giữ nguyên sau khi tái tạo container DB."