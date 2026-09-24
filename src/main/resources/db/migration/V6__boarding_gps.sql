-- V6: Store the student's GPS coordinates at the time of boarding.
-- Columns are nullable because GPS is optional and may be disabled.

ALTER TABLE boarding_records
    ADD COLUMN boarding_latitude  DECIMAL(10, 7) NULL COMMENT 'Student latitude at boarding time',
    ADD COLUMN boarding_longitude DECIMAL(10, 7) NULL COMMENT 'Student longitude at boarding time';
