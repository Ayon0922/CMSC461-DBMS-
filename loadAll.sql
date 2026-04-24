-- loadAll.sql (Partial sample: ensure 10 rows per table in your final file)

INSERT INTO Roles (role_name) VALUES ('Student'), ('Faculty'), ('Visitor'), ('Admin');

INSERT INTO Users (name, email, role_id) VALUES 
('Alice Smith', 'alice@umbc.edu', 1),
('Bob Lecturer', 'bob@umbc.edu', 2),
('Charlie Sneak', 'charlie@umbc.edu', 1);

INSERT INTO Vehicles (license_plate, make, model, color) VALUES 
('ABC-1234', 'Toyota', 'Camry', 'Silver'),
('FAC-9999', 'BMW', 'X5', 'Black'),
('GUEST-11', 'Honda', 'Civic', 'White');

INSERT INTO PermitTypes (type_name, cost, duration_days) VALUES 
('Commuter Student', 150.00, 180),
('Premium Faculty', 300.00, 365);

-- Example of an Expired Permit for testing 
INSERT INTO Permits (issue_date, expiry_date, vehicle_id, type_id) VALUES 
('2023-01-01', '2023-06-01', 1, 1);

INSERT INTO Lots (lot_name, location) VALUES ('Lot 4', 'North Campus'), ('Faculty Lot A', 'Administrative Drive');

INSERT INTO Spots (spot_number, spot_type, lot_id) VALUES (12, 'Student', 1), (1, 'Faculty', 2);

-- Example of an Unpaid Ticket 
INSERT INTO Tickets (fine_amount, status, vehicle_id, spot_id) VALUES (50.00, 'Issued', 3, 2);