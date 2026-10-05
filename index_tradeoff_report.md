# Báo Cáo Phân Tích Sự Đánh Đổi (Trade-off) Tài Nguyên Bảng SensorLogs

## 1. Bản chất sự cố tại SmartFactory
Hệ thống SmartFactory có tần suất ghi cực cao (Write-heavy IoT system: 10.000 cảm biến gửi dữ liệu liên tục). 
- **Fat Covering Index (`idx_fat_covering`):** Chứa toàn bộ 5 cột (`sensor_id`, `recorded_at`, `temperature`, `humidity`, `status`). Dù giúp câu lệnh `SELECT` Dashboard đọc thẳng trên cây B-Tree (Extra: `Using index`), nhưng nó gây ra **Write Penalty** nghiêm trọng: mỗi giây hệ thống phải thực hiện hàng chục nghìn thao tác chèn, sắp xếp lại nút lá và phân tách trang (Page Split) trên cây B-Tree cồng kềnh, gây nghẽn I/O và rớt gói tin (Data Loss).
- **Lãng phí Storage:** Kích thước Secondary Index phình to vượt cả dung lượng dữ liệu gốc do lưu trữ các trường dữ liệu biến động (`DECIMAL`, `VARCHAR`).

## 2. Giải pháp chuyển đổi sang Lean Index
- **Loại bỏ:** `idx_fat_covering` (gỡ bỏ các cột dữ liệu đo lường khỏi cây B-Tree).
- **Tạo mới:** `idx_lean_search(sensor_id, recorded_at)` – chỉ giữ lại 2 cột định danh và mốc thời gian dùng cho mệnh đề `WHERE` và `ORDER BY`.

## 3. Đánh giá sự đánh đổi (Trade-off Matrix)
- **Tốc độ Ghi (Write):** Tăng tốc gấp 3–5 lần, giải tỏa hàng đợi chèn dữ liệu thời gian thực.
- **Dung lượng (Storage & RAM Buffer Pool):** Dung lượng Index giảm hơn 65%, tiết kiệm hàng loạt chi phí lưu trữ SSD trên AWS.
- **Tốc độ Đọc (Read):** Chấp nhận thêm chi phí tra cứu bảng chính (Table Bookmark Lookup bằng `log_id`). Mặc dù mất `Using index`, chỉ mục vẫn giữ `type = range`, đảm bảo thời gian phản hồi của Dashboard ở mức vài mili-giây, hoàn toàn đáp ứng kỳ vọng của người dùng.
