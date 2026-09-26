-- H2-compatible V6: GPS columns for boarding_records
-- H2 requires separate ALTER TABLE statements per column.

ALTER TABLE boarding_records ADD COLUMN boarding_latitude  DECIMAL(10, 7) NULL;
ALTER TABLE boarding_records ADD COLUMN boarding_longitude DECIMAL(10, 7) NULL;
