Author: Ayon Rahman
Class: SP2026

Open the docker application first and then open the terminal and type "docker-compose up -d" to get things started
Open a browser and go to https://localhost:5050
Connection Info:
Host: umbc_parking_db (inside Docker network) or localhost (from host)
Username: admin@umbc.edu
Password: admin
Database: parking_db

FOLLOW THE EXACT EXECUTION ORDER:
    dropDDL.sql: Resets the environment by dropping existing tables and views.

    createDDL.sql: Creates the physical schema, triggers for sensor updates, and the auto-ticketing procedure.

    loadAll.sql: Populates the database with initial test data (minimum 10 rows per table). 

    indexAll.sql: Applies B-Tree and composite indexes to optimize expensive queries.

    queryAll.sql: Executes 10 course-level queries (joins, aggregations, subqueries) to demonstrate system functionality.

The system prevents double-booking anomalies through transaction locking. To reproduce the demo:
Open two separate Query Tool tabs in pgAdmin (Session A and Session B).
Disable Auto-commit in the execution settings for both tabs.
Session A: Run BEGIN; and the first INSERT from transaction.sql.
Session B: Run BEGIN; and the overlapping INSERT. Observe that the session blocks/hangs.
Session A: Run COMMIT;.
Session B: Observe the immediate conflict error as the database enforces integrity
