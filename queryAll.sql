-- queryAll.sql
-- 10 Course-Level SQL Queries for UMBC Parking Management

-- 1. Simple Join: List all users and their assigned roles
SELECT u.name, r.role_name 
FROM Users u 
JOIN Roles r ON u.role_id = r.role_id;

-- 2. Aggregation: Count the number of vehicles registered per user
SELECT u.name, COUNT(uv.vehicle_id) as vehicle_count
FROM Users u
LEFT JOIN User_Vehicles uv ON u.user_id = uv.user_id
GROUP BY u.name;

-- 3. Filtering & Joins: Find all active permits for 'Student' roles
SELECT v.license_plate, p.expiry_date
FROM Permits p
JOIN Vehicles v ON p.vehicle_id = v.vehicle_id
JOIN User_Vehicles uv ON v.vehicle_id = uv.vehicle_id
JOIN Users u ON uv.user_id = u.user_id
JOIN Roles r ON u.role_id = r.role_id
WHERE r.role_name = 'Student' AND p.expiry_date > CURRENT_DATE;

-- 4. Subquery: List lots that currently have no occupied spots
SELECT lot_name FROM Lots 
WHERE lot_id NOT IN (SELECT lot_id FROM Spots WHERE is_occupied = TRUE);

-- 5. Set Operations: Find users who have both a permit and a ticket
SELECT DISTINCT u.user_id, u.name FROM Users u
JOIN User_Vehicles uv ON u.user_id = uv.user_id
JOIN Permits p ON uv.vehicle_id = p.vehicle_id
INTERSECT
SELECT DISTINCT u.user_id, u.name FROM Users u
JOIN User_Vehicles uv ON u.user_id = uv.user_id
JOIN Tickets t ON uv.vehicle_id = t.vehicle_id;

-- 6. Complex Join: Show full history of sensor events for 'Lot 4'
SELECT l.lot_name, s.spot_number, se.event_type, se.event_timestamp
FROM Lots l
JOIN Spots s ON l.lot_id = s.lot_id
JOIN Sensors sn ON s.spot_id = sn.spot_id
JOIN SensorEvents se ON sn.sensor_id = se.sensor_id
WHERE l.lot_name = 'Lot 4'
ORDER BY se.event_timestamp DESC;

-- 7. Grouping with Having: Find lots with more than 5 available spots
SELECT l.lot_name, COUNT(s.spot_id) as available_count
FROM Lots l
JOIN Spots s ON l.lot_id = s.lot_id
WHERE s.is_occupied = FALSE
GROUP BY l.lot_name
HAVING COUNT(s.spot_id) > 5;

-- 8. EXPENSIVE QUERY 1: Multi-way join for detailed ticket reporting
-- This query scans multiple large tables to link users to fines.
EXPLAIN ANALYZE
SELECT u.name, v.license_plate, t.fine_amount, l.lot_name, t.issue_timestamp
FROM Users u
JOIN User_Vehicles uv ON u.user_id = uv.user_id
JOIN Vehicles v ON uv.vehicle_id = v.vehicle_id
JOIN Tickets t ON v.vehicle_id = t.vehicle_id
JOIN Spots s ON t.spot_id = s.spot_id
JOIN Lots l ON s.lot_id = l.lot_id
WHERE t.status = 'Issued';

-- 9. EXPENSIVE QUERY 2: Checking for reservation overlaps (Double-booking check)
-- Uses a cross join logic to find any conflicting time windows.
EXPLAIN ANALYZE
SELECT r1.res_id as res_a, r2.res_id as res_b, r1.spot_id
FROM Reservations r1
JOIN Reservations r2 ON r1.spot_id = r2.spot_id
WHERE r1.res_id <> r2.res_id
AND r1.start_time < r2.end_time 
AND r1.end_time > r2.start_time;

-- 10. EXPENSIVE QUERY 3: Calculate total revenue per permit type
EXPLAIN ANALYZE
SELECT pt.type_name, SUM(p.amount) as total_revenue
FROM PermitTypes pt
JOIN Permits pr ON pt.type_id = pr.type_id
JOIN Vehicles v ON pr.vehicle_id = v.vehicle_id
JOIN Tickets t ON v.vehicle_id = t.vehicle_id
JOIN Payments p ON t.ticket_id = p.ticket_id
GROUP BY pt.type_name;