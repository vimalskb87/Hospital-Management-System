""""
MediCore Hospital Management System
Flask Backend — MySQL Integration
Run: python app.py
"""


from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import pymysql
import pymysql.cursors

app = Flask(__name__)
CORS(app)

@app.route("/")
def index():
    return send_from_directory(".", "hospital_management.html")
# ─────────────────────────────────────────
#  DATABASE CONFIGURATION
#  Change these to match your MySQL setup
# ─────────────────────────────────────────
DB_CONFIG = {
    "host":     "127.0.0.1",
    "user":     "root",
    "password": "",            # ← make this empty
    "database": "hospital_db",
    "cursorclass": pymysql.cursors.DictCursor,
    "charset":  "utf8mb4",

}

def get_db():
    """Open a fresh database connection."""
    return pymysql.connect(**DB_CONFIG)


# ══════════════════════════════════════════
#  DASHBOARD — summary stats
# ══════════════════════════════════════════
@app.route("/api/dashboard", methods=["GET"])
def dashboard():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS total FROM patients")
            total_patients = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) AS total FROM patient_admissions WHERE status='Admitted'")
            admitted = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) AS total FROM appointments WHERE appointment_date = CURDATE() AND status='Scheduled'")
            todays_appts = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) AS total FROM staff WHERE status='Active' AND role='Doctor'")
            active_doctors = cur.fetchone()["total"]

            cur.execute("SELECT COUNT(*) AS total FROM medicines WHERE stock_qty <= reorder_level")
            low_stock = cur.fetchone()["total"]

            cur.execute("SELECT COALESCE(SUM(paid_amount),0) AS total FROM bills WHERE MONTH(bill_date)=MONTH(CURDATE())")
            monthly_revenue = cur.fetchone()["total"]

        return jsonify({
            "total_patients":  total_patients,
            "admitted":        admitted,
            "todays_appointments": todays_appts,
            "active_doctors":  active_doctors,
            "low_stock_medicines": low_stock,
            "monthly_revenue": float(monthly_revenue),
        })
    finally:
        db.close()


# ══════════════════════════════════════════
#  PATIENTS
# ══════════════════════════════════════════
@app.route("/api/patients", methods=["GET"])
def get_patients():
    search = request.args.get("search", "")
    db = get_db()
    try:
        with db.cursor() as cur:
            sql = """
                SELECT p.*,
                       a.admission_id, a.status AS admission_status,
                       r.room_number, w.ward_name,
                       CONCAT(s.first_name,' ',s.last_name) AS doctor_name
                FROM patients p
                LEFT JOIN patient_admissions a ON a.patient_id=p.patient_id AND a.status='Admitted'
                LEFT JOIN rooms r ON r.room_id=a.room_id
                LEFT JOIN wards w ON w.ward_id=r.ward_id
                LEFT JOIN doctors d ON d.doctor_id=a.admitted_by
                LEFT JOIN staff s ON s.staff_id=d.staff_id
                WHERE p.first_name LIKE %s OR p.last_name LIKE %s OR p.phone LIKE %s
                ORDER BY p.registered_at DESC
            """
            like = f"%{search}%"
            cur.execute(sql, (like, like, like))
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/patients/<int:pid>", methods=["GET"])
def get_patient(pid):
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT * FROM patients WHERE patient_id=%s", (pid,))
            patient = cur.fetchone()
            if not patient:
                return jsonify({"error": "Not found"}), 404

            cur.execute("""
                SELECT a.*, r.room_number, w.ward_name,
                       CONCAT(s.first_name,' ',s.last_name) AS doctor_name
                FROM patient_admissions a
                LEFT JOIN rooms r ON r.room_id=a.room_id
                LEFT JOIN wards w ON w.ward_id=r.ward_id
                LEFT JOIN doctors d ON d.doctor_id=a.admitted_by
                LEFT JOIN staff s ON s.staff_id=d.staff_id
                WHERE a.patient_id=%s ORDER BY a.admission_date DESC
            """, (pid,))
            patient["admissions"] = cur.fetchall()

            cur.execute("""
                SELECT b.*, COALESCE(SUM(pay.amount),0) AS paid_amount
                FROM bills b
                LEFT JOIN payments pay ON pay.bill_id=b.bill_id
                WHERE b.patient_id=%s GROUP BY b.bill_id
            """, (pid,))
            patient["bills"] = cur.fetchall()

        return jsonify(patient)
    finally:
        db.close()


@app.route("/api/patients", methods=["POST"])
def add_patient():
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                INSERT INTO patients
                  (first_name,last_name,dob,gender,blood_group,phone,email,
                   address,emergency_contact_name,emergency_contact_phone,allergies)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """, (
                data["first_name"], data["last_name"], data["dob"],
                data["gender"], data.get("blood_group"), data["phone"],
                data.get("email"), data.get("address"),
                data.get("emergency_contact_name"), data.get("emergency_contact_phone"),
                data.get("allergies"),
            ))
            db.commit()
            return jsonify({"success": True, "patient_id": cur.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  DOCTORS & STAFF
# ══════════════════════════════════════════
@app.route("/api/doctors", methods=["GET"])
def get_doctors():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                SELECT d.doctor_id, d.specialization, d.consultation_fee,
                       d.available_days, d.license_number,
                       s.staff_id, s.first_name, s.last_name, s.email,
                       s.phone, s.gender, s.status,
                       dep.dept_name
                FROM doctors d
                JOIN staff s ON s.staff_id=d.staff_id
                LEFT JOIN departments dep ON dep.dept_id=s.dept_id
                ORDER BY s.first_name
            """)
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/staff", methods=["GET"])
def get_staff():
    role = request.args.get("role", "")
    db = get_db()
    try:
        with db.cursor() as cur:
            if role:
                cur.execute("""
                    SELECT s.*, dep.dept_name FROM staff s
                    LEFT JOIN departments dep ON dep.dept_id=s.dept_id
                    WHERE s.role=%s ORDER BY s.first_name
                """, (role,))
            else:
                cur.execute("""
                    SELECT s.*, dep.dept_name FROM staff s
                    LEFT JOIN departments dep ON dep.dept_id=s.dept_id
                    ORDER BY s.role, s.first_name
                """)
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/staff", methods=["POST"])
def add_staff():
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                INSERT INTO staff
                  (first_name,last_name,role,dept_id,email,phone,gender,dob,hire_date,salary)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """, (
                data["first_name"], data["last_name"], data["role"],
                data.get("dept_id"), data["email"], data.get("phone"),
                data.get("gender"), data.get("dob"), data["hire_date"],
                data.get("salary"),
            ))
            db.commit()
            return jsonify({"success": True, "staff_id": cur.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  APPOINTMENTS
# ══════════════════════════════════════════
@app.route("/api/appointments", methods=["GET"])
def get_appointments():
    date_filter = request.args.get("date", "")
    status      = request.args.get("status", "")
    db = get_db()
    try:
        with db.cursor() as cur:
            sql = """
                SELECT a.*,
                       CONCAT(p.first_name,' ',p.last_name) AS patient_name,
                       CONCAT(s.first_name,' ',s.last_name) AS doctor_name,
                       d.specialization
                FROM appointments a
                JOIN patients p ON p.patient_id=a.patient_id
                JOIN doctors d  ON d.doctor_id=a.doctor_id
                JOIN staff s    ON s.staff_id=d.staff_id
                WHERE 1=1
            """
            params = []
            if date_filter:
                sql += " AND a.appointment_date=%s"
                params.append(date_filter)
            if status:
                sql += " AND a.status=%s"
                params.append(status)
            sql += " ORDER BY a.appointment_date DESC, a.appointment_time ASC"
            cur.execute(sql, params)
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/appointments", methods=["POST"])
def book_appointment():
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                INSERT INTO appointments
                  (patient_id,doctor_id,appointment_date,appointment_time,reason)
                VALUES (%s,%s,%s,%s,%s)
            """, (
                data["patient_id"], data["doctor_id"],
                data["appointment_date"], data["appointment_time"],
                data.get("reason", ""),
            ))
            db.commit()
            return jsonify({"success": True, "appointment_id": cur.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


@app.route("/api/appointments/<int:aid>", methods=["PUT"])
def update_appointment(aid):
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "UPDATE appointments SET status=%s, notes=%s WHERE appointment_id=%s",
                (data.get("status"), data.get("notes"), aid)
            )
            db.commit()
            return jsonify({"success": True})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  BILLING & PAYMENTS
# ══════════════════════════════════════════
@app.route("/api/bills", methods=["GET"])
def get_bills():
    status = request.args.get("status", "")
    db = get_db()
    try:
        with db.cursor() as cur:
            sql = """
                SELECT b.*,
                       CONCAT(p.first_name,' ',p.last_name) AS patient_name
                FROM bills b
                JOIN patients p ON p.patient_id=b.patient_id
            """
            params = []
            if status:
                sql += " WHERE b.status=%s"
                params.append(status)
            sql += " ORDER BY b.bill_date DESC"
            cur.execute(sql, params)
            bills = cur.fetchall()

            for bill in bills:
                cur.execute(
                    "SELECT * FROM bill_items WHERE bill_id=%s",
                    (bill["bill_id"],)
                )
                bill["items"] = cur.fetchall()

            return jsonify(bills)
    finally:
        db.close()


@app.route("/api/payments", methods=["POST"])
def record_payment():
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            # Insert payment
            cur.execute("""
                INSERT INTO payments
                  (bill_id,amount,payment_method,transaction_ref,received_by,notes)
                VALUES (%s,%s,%s,%s,%s,%s)
            """, (
                data["bill_id"], data["amount"], data["payment_method"],
                data.get("transaction_ref"), data.get("received_by"),
                data.get("notes"),
            ))

            # Update paid_amount on the bill and recalculate status
            cur.execute("""
                UPDATE bills
                SET paid_amount = paid_amount + %s,
                    status = CASE
                        WHEN paid_amount + %s >= total_amount THEN 'Paid'
                        WHEN paid_amount + %s > 0 THEN 'Partial'
                        ELSE status
                    END
                WHERE bill_id = %s
            """, (data["amount"], data["amount"], data["amount"], data["bill_id"]))

            db.commit()
            return jsonify({"success": True, "payment_id": cur.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  PHARMACY
# ══════════════════════════════════════════
@app.route("/api/medicines", methods=["GET"])
def get_medicines():
    low_stock = request.args.get("low_stock", "false").lower() == "true"
    db = get_db()
    try:
        with db.cursor() as cur:
            if low_stock:
                cur.execute("SELECT * FROM vw_low_stock_medicines ORDER BY stock_qty ASC")
            else:
                cur.execute("SELECT * FROM medicines ORDER BY name")
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/medicines", methods=["POST"])
def add_medicine():
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                INSERT INTO medicines
                  (name,generic_name,category,manufacturer,unit,unit_price,
                   stock_qty,reorder_level,expiry_date,requires_prescription)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            """, (
                data["name"], data.get("generic_name"), data.get("category"),
                data.get("manufacturer"), data.get("unit","Tablet"),
                data["unit_price"], data["stock_qty"], data.get("reorder_level",10),
                data.get("expiry_date"), data.get("requires_prescription", True),
            ))
            db.commit()
            return jsonify({"success": True, "medicine_id": cur.lastrowid}), 201
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


@app.route("/api/medicines/<int:mid>/restock", methods=["PUT"])
def restock_medicine(mid):
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "UPDATE medicines SET stock_qty = stock_qty + %s WHERE medicine_id=%s",
                (data["quantity"], mid)
            )
            db.commit()
            return jsonify({"success": True})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  WARDS & ROOMS
# ══════════════════════════════════════════
@app.route("/api/wards", methods=["GET"])
def get_wards():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                SELECT w.*, dep.dept_name,
                       (w.total_beds - w.available_beds) AS occupied_beds
                FROM wards w
                LEFT JOIN departments dep ON dep.dept_id=w.dept_id
                ORDER BY w.ward_name
            """)
            wards = cur.fetchall()

            for ward in wards:
                cur.execute(
                    "SELECT * FROM rooms WHERE ward_id=%s ORDER BY room_number",
                    (ward["ward_id"],)
                )
                ward["rooms"] = cur.fetchall()

            return jsonify(wards)
    finally:
        db.close()


@app.route("/api/rooms", methods=["GET"])
def get_rooms():
    status = request.args.get("status", "")
    db = get_db()
    try:
        with db.cursor() as cur:
            sql = "SELECT r.*, w.ward_name, w.ward_type FROM rooms r JOIN wards w ON w.ward_id=r.ward_id"
            if status:
                sql += " WHERE r.status=%s"
                cur.execute(sql, (status,))
            else:
                cur.execute(sql)
            return jsonify(cur.fetchall())
    finally:
        db.close()


@app.route("/api/rooms/<int:rid>/status", methods=["PUT"])
def update_room_status(rid):
    data = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "UPDATE rooms SET status=%s WHERE room_id=%s",
                (data["status"], rid)
            )
            db.commit()
            return jsonify({"success": True})
    except Exception as e:
        db.rollback()
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ══════════════════════════════════════════
#  RUN
# ══════════════════════════════════════════
if __name__ == "__main__":
    app.run(debug=True, port=5000)
