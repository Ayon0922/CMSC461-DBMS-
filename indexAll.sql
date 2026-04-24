-- Speed up license plate lookups (Critical for ticketing)
CREATE INDEX idx_vehicle_plate ON Vehicles(license_plate);

-- Composite index for reservation time windows (Critical for double-booking checks)
CREATE INDEX idx_res_time ON Reservations(start_time, end_time);

-- Speed up spot lookups by lot
CREATE INDEX idx_spot_lot ON Spots(lot_id);

-- Performance for permit expiry checks
CREATE INDEX idx_permit_expiry ON Permits(expiry_date);

-- Speed up user lookups by email
CREATE INDEX idx_user_email ON Users(email);