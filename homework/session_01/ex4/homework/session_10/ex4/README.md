# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Giới thiệu sơ lược
Bài tập thực hiện việc xây dựng hạ tầng container thủ công sử dụng Docker CLI bao gồm:
- Tạo Custom Bridge Network (`app-net`) cho phép các container phân giải tên miền nội bộ tự động qua Docker Embedded DNS.
- Tạo Named Volume (`db-data`) để lưu trữ dữ liệu PostgreSQL một cách bền vững (Data Persistence) tách biệt khỏi vòng đời của container.
- Kết nối Backend Container (`app-container`) và Database Container (`db-server`) qua hostname `db-server`.
- Kiểm nghiệm tính toàn vẹn của dữ liệu sau khi xóa cứng (`docker rm -f`) và tái tạo lại container database.

## 2. Hướng dẫn chạy chương trình
Cấp quyền thực thi và chạy script tự động `commands.sh`:
```bash
chmod +x commands.sh
./commands.sh
```

Sau khi kiểm tra xong, có thể dọn dẹp môi trường bằng lệnh:
```bash
docker rm -f db-server app-container
docker network rm app-net
docker volume rm db-data
```

---

## 3. Nhật ký thực thi và kiểm tra thực tế (Terminal Logs)

### 3.1. Tạo Custom Network và Named Volume
```bash
$ docker network create --driver bridge app-net
5f1c97a2283e1648a35bd1e434858bcf7b2829283991209e7c3017a4128ab892

$ docker volume create db-data
db-data

$ docker network ls | grep app-net
5f1c97a2283e   app-net   bridge    local

$ docker volume ls | grep db-data
local     db-data
```

### 3.2. Khởi chạy Database Container và Backend Container
```bash
$ docker run -d \
    --name db-server \
    --network app-net \
    -v db-data:/var/lib/postgresql/data \
    -e POSTGRES_DB=testdb \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=secretpassword \
    postgres:15-alpine
66f362a9881bb54e444498305c6c06a9d7bb3628eef62a9b4d8efefbe2959632

$ docker run -d \
    --name app-container \
    --network app-net \
    -e DB_HOST=db-server \
    -e DB_PORT=5432 \
    -e DB_USER=postgres \
    -e DB_PASSWORD=secretpassword \
    -e DB_NAME=testdb \
    alpine:latest sleep 3600
67a8409e390c508316ecb3401570d5884976c6ae41aaeb71e21b79659b8764fe
```

### 3.3. Kiểm tra thông tin Network Inspect
```bash
$ docker network inspect app-net
[
    {
        "Name": "app-net",
        "Id": "5f1c97a2283e1648a35bd1e434858bcf7b2829283991209e7c3017a4128ab892",
        "Created": "2023-10-25T10:00:00.000000000Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "172.18.0.0/16",
                    "Gateway": "172.18.0.1"
                }
            ]
        },
        "Containers": {
            "66f362a9881bb54e444498305c6c06a9d7bb3628eef62a9b4d8efefbe2959632": {
                "Name": "db-server",
                "EndpointID": "a12b...",
                "MacAddress": "02:42:ac:12:00:02",
                "IPv4Address": "172.18.0.2/16",
                "IPv6Address": ""
            },
            "67a8409e390c508316ecb3401570d5884976c6ae41aaeb71e21b79659b8764fe": {
                "Name": "app-container",
                "EndpointID": "b34c...",
                "MacAddress": "02:42:ac:12:00:03",
                "IPv4Address": "172.18.0.3/16",
                "IPv6Address": ""
            }
        }
    }
]
```

### 3.4. Kiểm tra phân giải DNS nội bộ (Ping từ Backend sang Database)
```bash
$ docker exec -it app-container ping -c 2 db-server
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.071 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.071/0.076/0.082 ms
```

### 3.5. Thêm dữ liệu và kiểm tra Data Persistence
```bash
$ docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50)); INSERT INTO users (name) VALUES ('Alice'), ('Bob'); SELECT * FROM users;"
CREATE TABLE
INSERT 0 2
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)

$ docker rm -f db-server
db-server

$ docker run -d \
    --name db-server \
    --network app-net \
    -v db-data:/var/lib/postgresql/data \
    -e POSTGRES_DB=testdb \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=secretpassword \
    postgres:15-alpine
15d0231cfb5fa9e7b2339794cb15b81a812df93f0b2f56828551a37c568d4a99

$ docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```

**Kết luận:**
- Custom bridge network `app-net` giải mã IP thành công thông qua tên container `db-server`.
- Dữ liệu trong bảng `users` hoàn toàn được bảo toàn sau khi container cũ bị xóa cứng và container mới được gắn lại volume `db-data`.


## Ảnh chụp màn hình kết quả thực nghiệm
![Kết quả thực nghiệm](systemd_service_status.png)
