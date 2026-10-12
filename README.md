# Bài 4: Custom Network & Named Volume bằng Docker CLI

## Mục tiêu
- Tạo Custom Bridge Network `app-net` để container gọi nhau qua tên (DNS nội bộ).
- Tạo Named Volume `db-data` để lưu dữ liệu PostgreSQL bền vững.

## Kiến trúc
```
app-container (Backend)  --app-net-->  db-server (postgres:15-alpine)
                                          |
                                   volume db-data -> /var/lib/postgresql/data
```

## Chạy
```bash
chmod +x commands.sh
./commands.sh

# Dùng image API thật (tùy chọn):
BACKEND_IMAGE=my-backend:latest ./commands.sh
```
Mặc định backend là `alpine:3.19` chạy nền để demo DNS; đặt `BACKEND_IMAGE` để dùng API thật (nhận biến `SPRING_DATASOURCE_URL`, `DB_HOST`, ... trỏ tới `db-server`).

## Các bước trong script
| Bước | Lệnh chính |
|------|-----------|
| Tạo network | `docker network create --driver bridge app-net` |
| Tạo volume | `docker volume create db-data` |
| Chạy DB | `docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data postgres:15-alpine` |
| Chạy Backend | `docker run -d --name app-container --network app-net -e SPRING_DATASOURCE_URL=jdbc:postgresql://db-server:5432/appdb ...` |
| Test persistence | Insert dữ liệu -> `docker rm -f db-server` -> chạy lại DB cùng volume -> `SELECT` |

## Lệnh kiểm tra
```bash
docker network ls | grep app-net
docker volume ls | grep db-data
docker network inspect app-net
docker exec -it app-container ping -c 2 db-server
```

## Kết quả mong đợi
- `ping db-server` từ `app-container` phân giải ra IP nội bộ của DB (ví dụ `172.x.x.x`).
- Sau `docker rm -f db-server` và tạo lại container gắn volume `db-data`, bảng `students` vẫn còn 2 bản ghi (`Poh`, `Docker`).

## Giải thích
- **Custom bridge** có DNS tích hợp, phân giải tên container; bridge mặc định thì không.
- **Named volume** do Docker quản lý, tồn tại độc lập với vòng đời container nên xóa container không mất dữ liệu.
- Postgres chỉ khởi tạo DB mới khi thư mục data trống; volume đã có dữ liệu thì dùng lại nguyên trạng.

## Dọn dẹp
```bash
docker rm -f app-container db-server
docker network rm app-net
docker volume rm db-data
```