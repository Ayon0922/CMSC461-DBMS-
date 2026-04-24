-- transaction.sql

-- ==========================================
-- STEP 1: OPEN SESSION A (User 1)
-- ==========================================
BEGIN;
-- Lock the table to ensure Session B must wait for evaluation
LOCK TABLE Reservations IN EXCLUSIVE MODE; 

INSERT INTO Reservations (start_time, end_time, status, user_id, spot_id)
VALUES ('2026-05-01 10:00:00', '2026-05-01 12:00:00', 'Confirmed', 1, 1);

-- DO NOT COMMIT YET. 

-- ==========================================
-- STEP 2: OPEN SESSION B (User 2)
-- ==========================================
BEGIN;
LOCK TABLE Reservations IN EXCLUSIVE MODE; 
-- NOTE: This session will now hang/block in pgAdmin until Session A finishes.

INSERT INTO Reservations (start_time, end_time, status, user_id, spot_id)
VALUES ('2026-05-01 11:00:00', '2026-05-01 13:00:00', 'Confirmed', 2, 1);

-- ==========================================
-- STEP 3: GO BACK TO SESSION A
-- ==========================================
COMMIT;

-- ==========================================
-- STEP 4: OBSERVE SESSION B
-- ==========================================
-- Session B will unblock. 
-- For the final project, ensure you have a trigger or constraint 
-- that checks for overlaps so Session B fails.
ROLLBACK;