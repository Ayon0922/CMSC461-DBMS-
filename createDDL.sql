-- createDDL.sql
-- Physical Schema Implementation

CREATE TABLE Roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    role_id INT REFERENCES Roles(role_id)
);

CREATE TABLE Vehicles (
    vehicle_id SERIAL PRIMARY KEY,
    license_plate VARCHAR(20) NOT NULL UNIQUE, -- Business Rule 1 [cite: 2299]
    make VARCHAR(50),
    model VARCHAR(50),
    color VARCHAR(20)
);

CREATE TABLE User_Vehicles (
    user_id INT REFERENCES Users(user_id),
    vehicle_id INT REFERENCES Vehicles(vehicle_id),
    PRIMARY KEY (user_id, vehicle_id) -- Composite PK [cite: 2304]
);

CREATE TABLE PermitTypes (
    type_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL,
    cost DECIMAL(10,2) NOT NULL CHECK (cost >= 0),
    duration_days INT NOT NULL
);

CREATE TABLE Permits (
    permit_id SERIAL PRIMARY KEY,
    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    vehicle_id INT REFERENCES Vehicles(vehicle_id),
    type_id INT REFERENCES PermitTypes(type_id),
    CHECK (expiry_date > issue_date)
);

CREATE TABLE Lots (
    lot_id SERIAL PRIMARY KEY,
    lot_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(255)
);

CREATE TABLE Spots (
    spot_id SERIAL PRIMARY KEY,
    spot_number INT NOT NULL,
    spot_type VARCHAR(50) NOT NULL,
    is_occupied BOOLEAN DEFAULT FALSE,
    lot_id INT REFERENCES Lots(lot_id),
    UNIQUE(lot_id, spot_number) -- A spot number must be unique within a lot
);

CREATE TABLE Reservations (
    res_id SERIAL PRIMARY KEY,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'Confirmed',
    user_id INT REFERENCES Users(user_id),
    spot_id INT REFERENCES Spots(spot_id),
    CHECK (end_time > start_time) -- Business Rule 3 [cite: 2301]
);

CREATE TABLE Sensors (
    sensor_id SERIAL PRIMARY KEY,
    sensor_model VARCHAR(100),
    spot_id INT REFERENCES Spots(spot_id) UNIQUE
);

CREATE TABLE SensorEvents (
    event_id SERIAL PRIMARY KEY,
    event_type VARCHAR(20) NOT NULL, -- Arrival/Departure
    event_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sensor_id INT REFERENCES Sensors(sensor_id)
);

CREATE TABLE Tickets (
    ticket_id SERIAL PRIMARY KEY,
    issue_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fine_amount DECIMAL(10,2) NOT NULL CHECK (fine_amount > 0), -- Business Rule 4 [cite: 2303]
    status VARCHAR(20) DEFAULT 'Issued',
    vehicle_id INT REFERENCES Vehicles(vehicle_id),
    spot_id INT REFERENCES Spots(spot_id)
);

CREATE TABLE Payments (
    payment_id SERIAL PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL,
    payment_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ticket_id INT REFERENCES Tickets(ticket_id)
);
CREATE OR REPLACE FUNCTION issue_permit(v_id INT, t_id INT, start_date DATE) 
RETURNS VOID AS $$
BEGIN
    -- Check if vehicle already has an active permit
    IF EXISTS (SELECT 1 FROM Permits WHERE vehicle_id = v_id AND expiry_date > start_date) THEN
        RAISE EXCEPTION 'Vehicle % already has an active permit.', v_id;
    END IF;

    INSERT INTO Permits (issue_date, expiry_date, vehicle_id, type_id)
    VALUES (start_date, start_date + interval '180 days', v_id, t_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_spot_occupancy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.event_type = 'Arrival' THEN
        UPDATE Spots SET is_occupied = TRUE WHERE spot_id = (SELECT spot_id FROM Sensors WHERE sensor_id = NEW.sensor_id);
    ELSIF NEW.event_type = 'Departure' THEN
        UPDATE Spots SET is_occupied = FALSE WHERE spot_id = (SELECT spot_id FROM Sensors WHERE sensor_id = NEW.sensor_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sensor_occupancy
AFTER INSERT ON SensorEvents
FOR EACH ROW EXECUTE FUNCTION update_spot_occupancy();

CREATE OR REPLACE PROCEDURE auto_generate_tickets()
AS $$
BEGIN
    -- This version links to the Tickets table correctly
    INSERT INTO Tickets (fine_amount, status, vehicle_id, spot_id)
    SELECT 50.00, 'Issued', 1, s.spot_id
    FROM Spots s
    WHERE s.is_occupied = TRUE; 
END;
$$ LANGUAGE plpgsql;

-- View 1: Current Lot Availability
CREATE VIEW CurrentLotAvailability AS
SELECT l.lot_name, COUNT(s.spot_id) AS available_spots
FROM Lots l
JOIN Spots s ON l.lot_id = s.lot_id
WHERE s.is_occupied = FALSE
GROUP BY l.lot_name;

-- View 2: Active Permits by User
CREATE VIEW ActivePermitUserList AS
SELECT u.name, v.license_plate, p.expiry_date
FROM Users u
JOIN User_Vehicles uv ON u.user_id = uv.user_id
JOIN Vehicles v ON uv.vehicle_id = v.vehicle_id
JOIN Permits p ON v.vehicle_id = p.vehicle_id
WHERE p.expiry_date > CURRENT_DATE;