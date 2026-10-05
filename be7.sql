-- ====================================================================
-- DỰ ÁN SMARTFACTORY: TỐI ƯU HÓA HỆ THỐNG IoT & CÂN BẰNG READ/WRITE
-- File: smartfactory_reindex.sql
-- ====================================================================

-- 1. Khởi tạo CSDL và cấu trúc bảng ban đầu
CREATE DATABASE IF NOT EXISTS smartfactory_db;
USE smartfactory_db;

DROP TABLE IF EXISTS SensorLogs;
CREATE TABLE SensorLogs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sensor_id INT NOT NULL,
    recorded_at DATETIME NOT NULL,
    temperature DECIMAL(5,2),
    humidity DECIMAL(5,2),
    status VARCHAR(20) -- 'NORMAL', 'WARNING', 'CRITICAL'
);

-- Tạo Fat Covering Index ban đầu (Legacy Script gây nghẽn Write và tốn dung lượng)
CREATE INDEX idx_fat_covering ON SensorLogs(sensor_id, recorded_at, temperature, humidity, status);

-- Thêm một số dữ liệu mẫu giả lập
INSERT INTO SensorLogs (sensor_id, recorded_at, temperature, humidity, status) VALUES
(105, '2026-06-20 08:00:00', 32.50, 65.00, 'NORMAL'),
(105, '2026-06-20 09:00:00', 36.80, 70.20, 'WARNING'),
(105, '2026-06-21 10:15:00', 42.10, 80.00, 'CRITICAL'),
(102, '2026-06-20 08:30:00', 28.30, 60.00, 'NORMAL');

-- --------------------------------------------------------------------
-- BƯỚC 1: KIỂM TRA DUNG LƯỢNG VÀ EXPLAIN KHI DÙNG FAT COVERING INDEX
-- --------------------------------------------------------------------
-- Đo lường dung lượng Data và Index
SELECT 
    table_name AS `Table`,
    ROUND(((data_length) / 1024 / 1024), 4) AS `Data_Size_MB`,
    ROUND(((index_length) / 1024 / 1024), 4) AS `Index_Size_MB`
FROM information_schema.TABLES
WHERE table_schema = 'smartfactory_db' AND table_name = 'SensorLogs';

-- EXPLAIN với Fat Index:
-- Kết quả: Extra = 'Using index' (Covering Index, không chạm bảng chính)
EXPLAIN SELECT temperature, humidity, status 
FROM SensorLogs 
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';


-- --------------------------------------------------------------------
-- BƯỚC 2: "CẮT BỎ" FAT INDEX VÀ THIẾT KẾ LEAN INDEX TINH GỌN
-- --------------------------------------------------------------------
-- 1. Xóa Fat Covering Index cồng kềnh
ALTER TABLE SensorLogs DROP INDEX idx_fat_covering;

-- 2. Tạo Lean Index chỉ chứa các cột dùng để LỌC và SẮP XẾP (WHERE / ORDER BY)
ALTER TABLE SensorLogs ADD INDEX idx_lean_search(sensor_id, recorded_at);


-- --------------------------------------------------------------------
-- BƯỚC 3: ĐỐI CHIẾU DUNG LƯỢNG VÀ KẾT QUẢ EXPLAIN SAU KHI TỐI ƯU
-- --------------------------------------------------------------------
-- Kiểm tra lại dung lượng (Index_Size_MB giảm mạnh)
SELECT 
    table_name AS `Table`,
    ROUND(((data_length) / 1024 / 1024), 4) AS `Data_Size_MB`,
    ROUND(((index_length) / 1024 / 1024), 4) AS `Index_Size_MB`
FROM information_schema.TABLES
WHERE table_schema = 'smartfactory_db' AND table_name = 'SensorLogs';

-- EXPLAIN với Lean Index:
-- Kết quả:
--   * type = 'range' (hoặc 'ref') -> Vẫn tối ưu tốc độ tìm kiếm bản ghi
--   * key = 'idx_lean_search'
--   * Extra không còn 'Using index' -> MySQL lookup bảng chính qua Primary Key
EXPLAIN SELECT temperature, humidity, status 
FROM SensorLogs 
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';