-- ============================================================
--  HOSPITAL MANAGEMENT SYSTEM — MySQL Schema
--  Modules: Patients, Doctors & Staff, Appointments,
--           Billing & Payments, Pharmacy, Wards & Rooms
-- ============================================================

CREATE DATABASE IF NOT EXISTS hospital_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE hospital_db;

-- ------------------------------------------------------------
-- 1. DEPARTMENTS
-- ------------------------------------------------------------
CREATE TABLE departments (
    dept_id       INT AUTO_INCREMENT PRIMARY KEY,
    dept_name     VARCHAR(100) NOT NULL,
    head_doctor_id INT,                      -- FK added after doctors table
    location      VARCHAR(100),
    phone         VARCHAR(20),
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- 2. WARDS & ROOMS
-- ------------------------------------------------------------
CREATE TABLE wards (
    ward_id      INT AUTO_INCREMENT PRIMARY KEY,
    ward_name    VARCHAR(100) NOT NULL,
    ward_type    ENUM('General','ICU','NICU','Surgery','Maternity','Pediatric','Isolation') NOT NULL,
    dept_id      INT,
    total_beds   INT NOT NULL DEFAULT 0,
    available_beds INT NOT NULL DEFAULT 0,
    floor_no     TINYINT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE SET NULL
);

CREATE TABLE rooms (
    room_id      INT AUTO_INCREMENT PRIMARY KEY,
    room_number  VARCHAR(20) NOT NULL UNIQUE,
    ward_id      INT NOT NULL,
    room_type    ENUM('Single','Double','Suite','ICU','Emergency') NOT NULL,
    status       ENUM('Available','Occupied','Under Maintenance') DEFAULT 'Available',
    daily_rate   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (ward_id) REFERENCES wards(ward_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 3. STAFF & DOCTORS
-- ------------------------------------------------------------
CREATE TABLE staff (
    staff_id      INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(60) NOT NULL,
    last_name     VARCHAR(60) NOT NULL,
    role          ENUM('Doctor','Nurse','Pharmacist','Lab Technician','Admin','Receptionist','Support') NOT NULL,
    dept_id       INT,
    email         VARCHAR(120) UNIQUE NOT NULL,
    phone         VARCHAR(20),
    address       TEXT,
    gender        ENUM('Male','Female','Other'),
    dob           DATE,
    hire_date     DATE NOT NULL,
    salary        DECIMAL(12,2),
    status        ENUM('Active','Inactive','On Leave') DEFAULT 'Active',
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE SET NULL
);

CREATE TABLE doctors (
    doctor_id         INT AUTO_INCREMENT PRIMARY KEY,
    staff_id          INT NOT NULL UNIQUE,
    specialization    VARCHAR(100) NOT NULL,
    qualification     VARCHAR(200),
    license_number    VARCHAR(50) UNIQUE NOT NULL,
    consultation_fee  DECIMAL(10,2) DEFAULT 0.00,
    available_days    SET('Mon','Tue','Wed','Thu','Fri','Sat','Sun'),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE CASCADE
);

-- Back-fill the FK for department head
ALTER TABLE departments
    ADD CONSTRAINT fk_dept_head
    FOREIGN KEY (head_doctor_id) REFERENCES doctors(doctor_id) ON DELETE SET NULL;

-- ------------------------------------------------------------
-- 4. PATIENTS
-- ------------------------------------------------------------
CREATE TABLE patients (
    patient_id    INT AUTO_INCREMENT PRIMARY KEY,
    first_name    VARCHAR(60) NOT NULL,
    last_name     VARCHAR(60) NOT NULL,
    dob           DATE NOT NULL,
    gender        ENUM('Male','Female','Other') NOT NULL,
    blood_group   ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-'),
    phone         VARCHAR(20) NOT NULL,
    email         VARCHAR(120),
    address       TEXT,
    emergency_contact_name  VARCHAR(120),
    emergency_contact_phone VARCHAR(20),
    medical_history         TEXT,
    allergies               TEXT,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE patient_admissions (
    admission_id  INT AUTO_INCREMENT PRIMARY KEY,
    patient_id    INT NOT NULL,
    room_id       INT,
    admitted_by   INT,               -- doctor_id
    admission_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    discharge_date DATETIME,
    diagnosis     TEXT,
    status        ENUM('Admitted','Discharged','Transferred','Deceased') DEFAULT 'Admitted',
    notes         TEXT,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id)    REFERENCES rooms(room_id) ON DELETE SET NULL,
    FOREIGN KEY (admitted_by) REFERENCES doctors(doctor_id) ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- 5. APPOINTMENTS
-- ------------------------------------------------------------
CREATE TABLE appointments (
    appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT NOT NULL,
    doctor_id        INT NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    reason           VARCHAR(255),
    status           ENUM('Scheduled','Completed','Cancelled','No-Show') DEFAULT 'Scheduled',
    notes            TEXT,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)  REFERENCES doctors(doctor_id)  ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 6. PHARMACY
-- ------------------------------------------------------------
CREATE TABLE medicines (
    medicine_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    generic_name  VARCHAR(150),
    category      VARCHAR(80),
    manufacturer  VARCHAR(120),
    unit          VARCHAR(30) DEFAULT 'Tablet',
    unit_price    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_qty     INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 10,
    expiry_date   DATE,
    requires_prescription BOOLEAN DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prescriptions (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id      INT NOT NULL,
    doctor_id       INT NOT NULL,
    appointment_id  INT,
    issued_date     DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes           TEXT,
    FOREIGN KEY (patient_id)     REFERENCES patients(patient_id)         ON DELETE CASCADE,
    FOREIGN KEY (doctor_id)      REFERENCES doctors(doctor_id)           ON DELETE CASCADE,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE SET NULL
);

CREATE TABLE prescription_items (
    item_id         INT AUTO_INCREMENT PRIMARY KEY,
    prescription_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    dosage          VARCHAR(80),
    frequency       VARCHAR(80),
    duration_days   INT,
    qty_prescribed  INT NOT NULL DEFAULT 1,
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id)     REFERENCES medicines(medicine_id)         ON DELETE RESTRICT
);

CREATE TABLE pharmacy_dispensing (
    dispense_id     INT AUTO_INCREMENT PRIMARY KEY,
    prescription_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    dispensed_by    INT,               -- staff_id of pharmacist
    qty_dispensed   INT NOT NULL,
    dispense_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id)     REFERENCES medicines(medicine_id)         ON DELETE RESTRICT,
    FOREIGN KEY (dispensed_by)    REFERENCES staff(staff_id)               ON DELETE SET NULL
);

-- ------------------------------------------------------------
-- 7. BILLING & PAYMENTS
-- ------------------------------------------------------------
CREATE TABLE bills (
    bill_id        INT AUTO_INCREMENT PRIMARY KEY,
    patient_id     INT NOT NULL,
    admission_id   INT,
    appointment_id INT,
    bill_date      DATETIME DEFAULT CURRENT_TIMESTAMP,
    due_date       DATE,
    subtotal       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    discount       DECIMAL(10,2) DEFAULT 0.00,
    tax            DECIMAL(10,2) DEFAULT 0.00,
    total_amount   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    paid_amount    DECIMAL(12,2) DEFAULT 0.00,
    balance        DECIMAL(12,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
    status         ENUM('Pending','Partial','Paid','Cancelled','Refunded') DEFAULT 'Pending',
    notes          TEXT,
    FOREIGN KEY (patient_id)     REFERENCES patients(patient_id)           ON DELETE CASCADE,
    FOREIGN KEY (admission_id)   REFERENCES patient_admissions(admission_id) ON DELETE SET NULL,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)   ON DELETE SET NULL
);

CREATE TABLE bill_items (
    item_id      INT AUTO_INCREMENT PRIMARY KEY,
    bill_id      INT NOT NULL,
    description  VARCHAR(255) NOT NULL,
    item_type    ENUM('Consultation','Room','Medicine','Lab','Surgery','Procedure','Other') NOT NULL,
    quantity     INT DEFAULT 1,
    unit_price   DECIMAL(10,2) NOT NULL,
    total_price  DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (bill_id) REFERENCES bills(bill_id) ON DELETE CASCADE
);

CREATE TABLE payments (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    bill_id        INT NOT NULL,
    amount         DECIMAL(12,2) NOT NULL,
    payment_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
    payment_method ENUM('Cash','Card','UPI','Net Banking','Insurance','Cheque') NOT NULL,
    transaction_ref VARCHAR(100),
    received_by    INT,               -- staff_id
    notes          TEXT,
    FOREIGN KEY (bill_id)       REFERENCES bills(bill_id)    ON DELETE CASCADE,
    FOREIGN KEY (received_by)   REFERENCES staff(staff_id)   ON DELETE SET NULL
);

CREATE TABLE insurance_claims (
    claim_id       INT AUTO_INCREMENT PRIMARY KEY,
    bill_id        INT NOT NULL,
    patient_id     INT NOT NULL,
    provider_name  VARCHAR(150) NOT NULL,
    policy_number  VARCHAR(100) NOT NULL,
    claim_amount   DECIMAL(12,2) NOT NULL,
    approved_amount DECIMAL(12,2),
    status         ENUM('Submitted','Under Review','Approved','Rejected','Paid') DEFAULT 'Submitted',
    submitted_date DATE,
    resolved_date  DATE,
    FOREIGN KEY (bill_id)    REFERENCES bills(bill_id)       ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- 8. AUDIT / SYSTEM LOGS
-- ------------------------------------------------------------
CREATE TABLE system_users (
    user_id      INT AUTO_INCREMENT PRIMARY KEY,
    staff_id     INT UNIQUE NOT NULL,
    username     VARCHAR(60) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role         ENUM('Admin','Doctor','Nurse','Pharmacist','Receptionist','Billing') NOT NULL,
    is_active    BOOLEAN DEFAULT TRUE,
    last_login   DATETIME,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON DELETE CASCADE
);

-- ------------------------------------------------------------
-- USEFUL VIEWS
-- ------------------------------------------------------------

-- Patient overview with current admission
CREATE OR REPLACE VIEW vw_patient_overview AS
SELECT
    p.patient_id,
    CONCAT(p.first_name,' ',p.last_name) AS patient_name,
    p.dob, p.gender, p.blood_group, p.phone,
    a.admission_id, a.admission_date, a.status AS admission_status,
    r.room_number, w.ward_name,
    CONCAT(s.first_name,' ',s.last_name) AS attending_doctor
FROM patients p
LEFT JOIN patient_admissions a ON a.patient_id = p.patient_id AND a.status = 'Admitted'
LEFT JOIN rooms r              ON r.room_id    = a.room_id
LEFT JOIN wards w              ON w.ward_id    = r.ward_id
LEFT JOIN doctors doc          ON doc.doctor_id = a.admitted_by
LEFT JOIN staff s              ON s.staff_id    = doc.staff_id;

-- Doctor schedule
CREATE OR REPLACE VIEW vw_doctor_schedule AS
SELECT
    d.doctor_id,
    CONCAT(s.first_name,' ',s.last_name) AS doctor_name,
    d.specialization,
    d.consultation_fee,
    d.available_days,
    dep.dept_name,
    COUNT(ap.appointment_id) AS total_appointments_today
FROM doctors d
JOIN staff s         ON s.staff_id  = d.staff_id
LEFT JOIN departments dep ON dep.dept_id = s.dept_id
LEFT JOIN appointments ap ON ap.doctor_id = d.doctor_id
    AND ap.appointment_date = CURDATE()
    AND ap.status = 'Scheduled'
GROUP BY d.doctor_id, doctor_name, d.specialization, d.consultation_fee, d.available_days, dep.dept_name;

-- Outstanding bills
CREATE OR REPLACE VIEW vw_outstanding_bills AS
SELECT
    b.bill_id,
    CONCAT(p.first_name,' ',p.last_name) AS patient_name,
    b.bill_date, b.total_amount, b.paid_amount, b.balance, b.status
FROM bills b
JOIN patients p ON p.patient_id = b.patient_id
WHERE b.status IN ('Pending','Partial')
ORDER BY b.balance DESC;

-- Low stock medicines
CREATE OR REPLACE VIEW vw_low_stock_medicines AS
SELECT
    medicine_id, name, generic_name, category,
    stock_qty, reorder_level, expiry_date
FROM medicines
WHERE stock_qty <= reorder_level
ORDER BY stock_qty ASC;

-- ------------------------------------------------------------
-- SAMPLE SEED DATA
-- ------------------------------------------------------------

INSERT INTO departments (dept_name, location, phone) VALUES
('Cardiology',    'Block A, Floor 2', '0512-300-101'),
('Neurology',     'Block B, Floor 1', '0512-300-102'),
('Orthopedics',   'Block C, Floor 3', '0512-300-103'),
('Pediatrics',    'Block A, Floor 1', '0512-300-104'),
('General Medicine','Block D, Floor 1','0512-300-105'),
('Pharmacy',      'Ground Floor',     '0512-300-200');

INSERT INTO wards (ward_name, ward_type, dept_id, total_beds, available_beds, floor_no) VALUES
('Cardiac Ward',     'ICU',      1, 10, 4, 2),
('Neuro Ward',       'General',  2, 20, 12, 1),
('Ortho Ward',       'General',  3, 15, 9, 3),
('Pediatric Ward',   'Pediatric',4, 18, 10, 1),
('General Ward',     'General',  5, 30, 18, 1),
('Emergency',        'ICU',      5,  8,  3, 0);

INSERT INTO rooms (room_number, ward_id, room_type, status, daily_rate) VALUES
('A-101','1','ICU',      'Available', 5000.00),
('A-102','1','ICU',      'Occupied',  5000.00),
('B-201','2','Single',   'Available', 2500.00),
('B-202','2','Double',   'Available', 1800.00),
('C-301','3','Single',   'Occupied',  2200.00),
('D-101','4','Single',   'Available', 2000.00),
('E-101','5','Double',   'Available',  900.00),
('E-102','5','Suite',    'Available', 4500.00),
('ER-01', '6','Emergency','Occupied', 3500.00);

INSERT INTO staff (first_name,last_name,role,dept_id,email,phone,gender,dob,hire_date,salary) VALUES
('Arun',   'Sharma',   'Doctor',      1,'arun.sharma@hospital.com',   '9876543210','Male',  '1978-05-12','2010-06-01',150000),
('Priya',  'Mehta',    'Doctor',      2,'priya.mehta@hospital.com',   '9876543211','Female','1982-08-22','2012-03-15',140000),
('Rakesh', 'Verma',    'Doctor',      3,'rakesh.verma@hospital.com',  '9876543212','Male',  '1975-11-30','2008-01-10',160000),
('Sunita', 'Singh',    'Nurse',       1,'sunita.singh@hospital.com',  '9876543213','Female','1990-04-18','2015-07-01', 45000),
('Mohit',  'Jain',     'Pharmacist',  6,'mohit.jain@hospital.com',    '9876543214','Male',  '1988-02-14','2016-09-01', 50000),
('Kavita', 'Rao',      'Receptionist',5,'kavita.rao@hospital.com',    '9876543215','Female','1993-07-25','2019-01-15', 35000),
('Deepak', 'Gupta',    'Doctor',      4,'deepak.gupta@hospital.com',  '9876543216','Male',  '1980-09-07','2011-04-01',145000),
('Neha',   'Agarwal',  'Admin',       5,'neha.agarwal@hospital.com',  '9876543217','Female','1985-12-03','2013-08-01', 60000);

INSERT INTO doctors (staff_id, specialization, qualification, license_number, consultation_fee, available_days) VALUES
(1,'Cardiology',   'MD, DM Cardiology',     'MCI-CARD-001', 800.00, 'Mon,Tue,Wed,Thu,Fri'),
(2,'Neurology',    'MD, DM Neurology',      'MCI-NEUR-002', 900.00, 'Mon,Wed,Fri'),
(3,'Orthopedics',  'MS Orthopedics',        'MCI-ORTH-003', 700.00, 'Tue,Thu,Sat'),
(7,'Pediatrics',   'MD Pediatrics, MRCP',   'MCI-PEDI-004', 600.00, 'Mon,Tue,Wed,Thu,Fri');

INSERT INTO patients (first_name,last_name,dob,gender,blood_group,phone,email,address,emergency_contact_name,emergency_contact_phone) VALUES
('Ramesh',  'Kumar',   '1965-03-10','Male',  'B+','9811111111','ramesh.k@email.com',  'Civil Lines, Kanpur','Suresh Kumar',   '9811111112'),
('Anita',   'Patel',   '1990-07-22','Female','A+','9822222222','anita.p@email.com',   'Swaroop Nagar, Kanpur','Rajesh Patel', '9822222223'),
('Vikas',   'Tiwari',  '1978-11-05','Male',  'O-','9833333333','vikas.t@email.com',   'Kidwai Nagar, Kanpur','Meena Tiwari',  '9833333334'),
('Shalini', 'Mishra',  '2001-01-15','Female','AB+','9844444444','shalini.m@email.com','Kakadeo, Kanpur',     'Sunil Mishra',  '9844444445'),
('Amit',    'Srivastava','1955-06-28','Male', 'A-','9855555555','amit.s@email.com',   'Armapur, Kanpur',     'Rita Srivastava','9855555556');

INSERT INTO patient_admissions (patient_id,room_id,admitted_by,admission_date,diagnosis,status) VALUES
(1,2,1,'2026-03-20 10:30:00','Acute Myocardial Infarction','Admitted'),
(3,5,3,'2026-03-21 14:00:00','Fractured Femur','Admitted'),
(5,9,1,'2026-03-23 08:15:00','Chest Pain - Under Observation','Admitted');

INSERT INTO appointments (patient_id,doctor_id,appointment_date,appointment_time,reason,status) VALUES
(2,1,'2026-03-25','10:00:00','Routine cardiac checkup','Scheduled'),
(4,2,'2026-03-25','11:30:00','Recurring headaches','Scheduled'),
(2,3,'2026-03-26','09:00:00','Knee pain follow-up','Scheduled'),
(1,1,'2026-03-15','10:00:00','Initial consultation','Completed'),
(3,3,'2026-03-18','09:30:00','Pre-surgery assessment','Completed');

INSERT INTO medicines (name,generic_name,category,manufacturer,unit,unit_price,stock_qty,reorder_level,expiry_date) VALUES
('Aspirin 75mg',    'Aspirin',          'Antiplatelet','Sun Pharma',    'Tablet', 2.50, 500, 50,'2027-12-31'),
('Atorvastatin 20mg','Atorvastatin',    'Statin',      'Cipla',         'Tablet', 8.00, 300, 30,'2027-06-30'),
('Metformin 500mg', 'Metformin HCl',   'Antidiabetic','Dr. Reddys',    'Tablet', 3.50, 200, 25,'2026-09-30'),
('Paracetamol 500mg','Paracetamol',    'Analgesic',   'GSK India',     'Tablet', 1.50, 800, 100,'2027-03-31'),
('Amoxicillin 500mg','Amoxicillin',    'Antibiotic',  'Mankind Pharma','Capsule',12.00,  15, 20,'2026-12-31'),
('Normal Saline 500ml','Sodium Chloride','IV Fluid',  'Baxter',        'Bottle',120.00, 60, 15,'2026-08-31'),
('Omeprazole 20mg', 'Omeprazole',      'PPI',         'Torrent Pharma','Capsule',5.00, 400, 40,'2027-01-31'),
('Ceftriaxone 1g',  'Ceftriaxone',     'Antibiotic',  'Sun Pharma',    'Vial', 180.00,   8, 10,'2026-10-31');

INSERT INTO bills (patient_id,admission_id,bill_date,due_date,subtotal,tax,total_amount,paid_amount,status) VALUES
(1,1,'2026-03-20',STR_TO_DATE('2026-04-20','%Y-%m-%d'),25000.00,0.00,25000.00,10000.00,'Partial'),
(3,2,'2026-03-21',STR_TO_DATE('2026-04-21','%Y-%m-%d'),18000.00,0.00,18000.00,18000.00,'Paid'),
(5,3,'2026-03-23',STR_TO_DATE('2026-04-23','%Y-%m-%d'),12000.00,0.00,12000.00,0.00,'Pending');

INSERT INTO bill_items (bill_id,description,item_type,quantity,unit_price,total_price) VALUES
(1,'ICU Room (4 days)','Room',4,5000.00,20000.00),
(1,'Cardiologist Consultation','Consultation',1,800.00,800.00),
(1,'ECG & Echo','Procedure',2,2100.00,4200.00),
(2,'Single Room (3 days)','Room',3,2200.00,6600.00),
(2,'Orthopaedic Consultation','Consultation',1,700.00,700.00),
(2,'Fracture Surgery','Surgery',1,10000.00,10000.00),
(3,'Emergency Room (2 days)','Room',2,3500.00,7000.00),
(3,'Cardiologist Consultation','Consultation',1,800.00,800.00),
(3,'Medicines & Supplies','Medicine',1,4200.00,4200.00);

INSERT INTO payments (bill_id,amount,payment_method,transaction_ref,received_by) VALUES
(1,10000.00,'UPI','UPI20260320ABC',6),
(2,18000.00,'Card','CARD20260322XYZ',6);

-- END OF SCHEMA
