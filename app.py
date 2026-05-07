import streamlit as st
import psycopg2
import pandas as pd
from datetime import datetime, date, timedelta

# ============================================================
# DATABASE CONNECTION & HELPER
# ============================================================
def init_connection():
    return psycopg2.connect(
        host="localhost",
        database="parking_db",
        user="umbc_admin",
        password="umbc_password"
    )

try:
    conn = init_connection()
    conn.autocommit = False
except Exception as e:
    st.error(f"Failed to connect to the database. Error: {e}")
    st.stop()

def run_query(query, params=None, commit=False):
    """Execute a query and return results as a DataFrame, or None for DML."""
    try:
        with conn.cursor() as cur:
            cur.execute(query, params)
            if cur.description:
                columns = [desc[0] for desc in cur.description]
                rows = cur.fetchall()
                if commit: conn.commit()
                return pd.DataFrame(rows, columns=columns)
            else:
                if commit: conn.commit()
                return None
    except Exception as e:
        conn.rollback()
        raise e

# ============================================================
# UI SETUP
# ============================================================
st.set_page_config(page_title="UMBC Parking Admin", layout="wide")
st.title("🐾 UMBC Parking Management System")
st.markdown("---")

tabs = st.tabs([
    "Dashboard", "Lots & Sensors", "Permits", 
    "Reservations", "Enforcement", "Payments", 
    "SQL Reports", "Concurrency Demo"
])

# ==============================================================
# TAB 1: DASHBOARD
# ==============================================================
with tabs[0]:
    st.header("System Dashboard")
    
    try:
        c1, c2, c3, c4, c5, c6 = st.columns(6)
        c1.metric("Total Spots", run_query("SELECT COUNT(*) AS n FROM Spots;")["n"][0])
        c2.metric("Available Spots", run_query("SELECT COUNT(*) AS n FROM Spots WHERE is_occupied = FALSE;")["n"][0])
        c3.metric("Active Permits", run_query("SELECT COUNT(*) AS n FROM Permits WHERE expiry_date > CURRENT_DATE;")["n"][0])
        c4.metric("Open Tickets", run_query("SELECT COUNT(*) AS n FROM Tickets WHERE status = 'Issued';")["n"][0])
        c5.metric("Users", run_query("SELECT COUNT(*) AS n FROM Users;")["n"][0])
        rev = run_query("SELECT COALESCE(SUM(amount),0) AS n FROM Payments;")["n"][0]
        c6.metric("Total Revenue", f"${float(rev):,.2f}")
    except Exception as e:
        st.error(f"Could not load metrics: {e}")

    st.markdown("---")
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Real-Time Lot Availability")
        st.dataframe(run_query("SELECT * FROM CurrentLotAvailability ORDER BY available_spots DESC;"), use_container_width=True)
    with col2:
        st.subheader("Recent Sensor Events")
        st.dataframe(run_query("""
            SELECT se.event_type, se.event_timestamp, l.lot_name, sp.spot_number
            FROM SensorEvents se
            JOIN Sensors sn ON se.sensor_id = sn.sensor_id
            JOIN Spots sp ON sn.spot_id = sp.spot_id
            JOIN Lots l ON sp.lot_id = l.lot_id
            ORDER BY se.event_timestamp DESC LIMIT 10;
        """), use_container_width=True)

# ==============================================================
# TAB 2: LOTS & SENSORS
# ==============================================================
with tabs[1]:
    st.header("Parking Lots & Sensor Simulation")
    
    col_a, col_b = st.columns([2, 1])
    with col_a:
        st.dataframe(run_query("""
            SELECT l.lot_name, sp.spot_number, sp.spot_type, sp.is_occupied
            FROM Spots sp JOIN Lots l ON sp.lot_id = l.lot_id ORDER BY l.lot_name, sp.spot_number;
        """), use_container_width=True)
        
    with col_b:
        st.subheader("Simulate Sensor Event")
        try:
            sensors_df = run_query("""
                SELECT sn.sensor_id, CONCAT(l.lot_name, ' - Spot ', sp.spot_number) AS label
                FROM Sensors sn JOIN Spots sp ON sn.spot_id = sp.spot_id JOIN Lots l ON sp.lot_id = l.lot_id
            """)
            s_map = dict(zip(sensors_df["label"], sensors_df["sensor_id"]))
            
            sel_sensor = st.selectbox("Select Spot", list(s_map.keys()))
            event_type = st.radio("Event Type", ["Arrival", "Departure"])
            
            if st.button("Fire Event", type="primary"):
                try:
                    run_query("INSERT INTO SensorEvents (event_type, sensor_id) VALUES (%s, %s);", (event_type, s_map[sel_sensor]), commit=True)
                    st.success("Trigger fired successfully!")
                    st.experimental_rerun()
                except Exception as e:
                    st.error(f"Error: {e}")
        except Exception as e:
            st.error(f"Error loading sensors: {e}")

# ==============================================================
# TAB 3: PERMITS
# ==============================================================
with tabs[2]:
    st.header("Permit Management")
    
    col1, col2 = st.columns([1, 2])
    with col1:
        st.subheader("Issue Permit")
        try:
            v_df = run_query("SELECT vehicle_id, license_plate FROM Vehicles;")
            p_df = run_query("SELECT type_id, type_name FROM PermitTypes;")
            v_map = dict(zip(v_df["license_plate"], v_df["vehicle_id"]))
            p_map = dict(zip(p_df["type_name"], p_df["type_id"]))
            
            sel_veh = st.selectbox("Vehicle", list(v_map.keys()))
            sel_type = st.selectbox("Permit Type", list(p_map.keys()))
            start_dt = st.date_input("Start Date")
            
            if st.button("Issue Permit"):
                try:
                    run_query("SELECT issue_permit(%s, %s, %s);", (v_map[sel_veh], p_map[sel_type], start_dt), commit=True)
                    st.success("Permit Issued!")
                    st.experimental_rerun()
                except Exception as e:
                    st.error(f"Transaction Failed: {e}")
        except Exception as e:
            st.error(e)

    with col2:
        st.subheader("Active Permits")
        st.dataframe(run_query("SELECT * FROM ActivePermitUserList;"), use_container_width=True)

# ==============================================================
# TAB 4: RESERVATIONS
# ==============================================================
with tabs[3]:
    st.header("Reservations")
    st.dataframe(run_query("""
        SELECT r.res_id, u.name, l.lot_name, sp.spot_number, r.start_time, r.end_time, r.status
        FROM Reservations r JOIN Users u ON r.user_id = u.user_id JOIN Spots sp ON r.spot_id = sp.spot_id JOIN Lots l ON sp.lot_id = l.lot_id
        ORDER BY r.start_time DESC;
    """), use_container_width=True)

# ==============================================================
# TAB 5: ENFORCEMENT
# ==============================================================
with tabs[4]:
    st.header("Enforcement")
    if st.button("Run Auto-Ticketing Protocol", type="primary"):
        try:
            run_query("CALL auto_generate_tickets();", commit=True)
            st.success("Auto-ticketing executed!")
            st.experimental_rerun()
        except Exception as e:
            st.error(f"Failed: {e}")
            
    st.dataframe(run_query("""
        SELECT t.ticket_id, v.license_plate, t.fine_amount, t.status, l.lot_name, sp.spot_number
        FROM Tickets t JOIN Vehicles v ON t.vehicle_id = v.vehicle_id JOIN Spots sp ON t.spot_id = sp.spot_id JOIN Lots l ON sp.lot_id = l.lot_id
        ORDER BY t.issue_timestamp DESC;
    """), use_container_width=True)


# ==============================================================
# TAB 6: CONCURRENCY DEMO
# ==============================================================
with tabs[5]:
    st.header("Concurrency Control Demo")
    col1, col2 = st.columns(2)
    
    # Using hardcoded spot_id 1 for the demo (Lot 4 - Spot 12)
    with col1:
        st.subheader("Session A (User 1)")
        if st.button("Run Session A (Should Succeed)"):
            try:
                run_query("INSERT INTO Reservations (start_time, end_time, status, user_id, spot_id) VALUES (%s, %s, 'Confirmed', 1, 1);", 
                          ("2026-06-01 09:00", "2026-06-01 11:00"), commit=True)
                st.success("Session A Committed.")
            except Exception as e:
                st.warning(f"Blocked: {e}")
                
    with col2:
        st.subheader("Session B (User 2 - Overlap)")
        if st.button("Run Session B (Should Fail)", type="primary"):
            try:
                run_query("INSERT INTO Reservations (start_time, end_time, status, user_id, spot_id) VALUES (%s, %s, 'Confirmed', 2, 1);", 
                          ("2026-06-01 10:00", "2026-06-01 12:00"), commit=True)
                st.warning("Session B succeeded (Run A first!)")
            except Exception as e:
                st.error(f"Session B Rejected by Trigger:\n{e}")