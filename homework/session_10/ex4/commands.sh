#!/usr/bin/env bash
set -euo pipefail

echo "=== BƯỚC 1: TẠO CUSTOM BRIDGE NETWORK VÀ NAMED VOLUME ==="
docker network create --driver bridge app-net || true
docker volume create db-data || true

echo "=== BƯỚC 2: KHỞI CHẠY POSTGRESQL DATABASE CONTAINER (db-server) ==="
docker rm -f db-server 2>/dev/null || true
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword \
  postgres:15-alpine

echo "Đang đợi Database khởi động hoàn tất..."
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  sleep 2
done
echo "Database db-server đã sẵn sàng!"

echo "=== BƯỚC 3: KHỞI CHẠY BACKEND CONTAINER (app-container) ==="
docker rm -f app-container 2>/dev/null || true
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=secretpassword \
  -e DB_NAME=testdb \
  alpine:latest sleep 3600

echo "=== BƯỚC 4: TEST DNS RESOLUTION GIỮA CÁC CONTAINER QUA CUSTOM NETWORK ==="
docker exec app-container ping -c 2 db-server

echo "=== BƯỚC 5: TẠO DỮ LIỆU BAN ĐẦU TRONG DATABASE ==="
docker exec -i db-server psql -U postgres -d testdb <<'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (name) VALUES ('Alice'), ('Bob');
SELECT * FROM users;
EOF

echo "=== BƯỚC 6: XÓA CỨNG CONTAINER DB (TEST DATA PERSISTENCE) ==="
echo "Đang xóa cứng container db-server..."
docker rm -f db-server

echo "=== BƯỚC 7: TẠO LẠI DB CONTAINER MỚI DÙNG CHUNG VOLUME db-data ==="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secretpassword \
  postgres:15-alpine

echo "Đang đợi Database mới khởi động..."
until docker exec db-server pg_isready -U postgres -d testdb >/dev/null 2>&1; do
  sleep 2
done

echo "=== BƯỚC 8: XÁC MINH DỮ LIỆU KHÔNG BỊ MẤT ==="
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "=== HOÀN TẤT THỬ NGHIỆM THÀNH CÔNG ==="
