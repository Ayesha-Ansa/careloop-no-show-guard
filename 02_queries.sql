-- CareLoop Clinics — No-Show Guard
-- Part 2: SQL analysis (MySQL 8)
-- Run the setup section once on a clean MySQL server/database.

-- =========================================================
-- Task 2.1 — Create database and tables
-- =========================================================

CREATE DATABASE IF NOT EXISTS noshowguard;
USE noshowguard;

CREATE TABLE clinics (
    clinic_id VARCHAR(5) PRIMARY KEY,
    clinic_name VARCHAR(40) NOT NULL,
    city VARCHAR(20) NOT NULL,
    tier VARCHAR(10),
    latitude DECIMAL(8,4),
    longitude DECIMAL(8,4),
    temp_c DECIMAL(5,1)
);

CREATE TABLE appointments (
    appointment_id VARCHAR(8) PRIMARY KEY,
    patient_id VARCHAR(8) NOT NULL,
    clinic_id VARCHAR(5) NOT NULL,
    booked_on DATE,
    appt_date DATE,
    age INT,
    gender VARCHAR(1),
    distance_km DECIMAL(5,1),
    fee_inr INT,
    booking_channel VARCHAR(10),
    visit_type VARCHAR(12),
    reminder_sent VARCHAR(3),
    prior_no_shows INT,
    status VARCHAR(10),
    lead_days INT,
    no_show INT,
    FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
);

-- Run load_data.sql separately after creating the tables.
-- It inserts clinics first, followed by appointments.

-- Verify loaded records.
SELECT COUNT(*) AS clinic_count
FROM clinics;

SELECT
    COUNT(*) AS appointment_count,
    SUM(no_show) AS no_show_count
FROM appointments;

-- Duplicate primary-key test was executed separately.
-- It was intentionally not left active to avoid failing a full-script run.
-- INSERT INTO appointments
-- SELECT *
-- FROM appointments
-- WHERE appointment_id = 'A0001';
--
-- Actual MySQL Workbench Action Output:
-- Error Code: 1062. Duplicate entry 'A0001' for key 'appointments.PRIMARY'

-- =========================================================
-- Task 2.2 — No-show rate by clinic (at least 95 appointments)
-- =========================================================

SELECT
    c.clinic_name,
    c.city,
    COUNT(*) AS appointments,
    SUM(a.no_show) AS no_shows,
    ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments AS a
JOIN clinics AS c
    ON c.clinic_id = a.clinic_id
GROUP BY
    c.clinic_name,
    c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;

-- Task 2.2 — All eight clinics (HAVING removed).
SELECT
    c.clinic_name,
    c.city,
    COUNT(*) AS appointments,
    SUM(a.no_show) AS no_shows,
    ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments AS a
JOIN clinics AS c
    ON c.clinic_id = a.clinic_id
GROUP BY
    c.clinic_name,
    c.city
ORDER BY no_show_pct DESC;

-- All-clinic result: Gomti Nagar Care Point (Lucknow) is highest
-- at 33.3% with 90 appointments.

-- =========================================================
-- Task 2.3 — No-show rate by booking lead-time band
-- =========================================================

SELECT
    CASE
        WHEN lead_days BETWEEN 1 AND 7 THEN '1-7'
        WHEN lead_days BETWEEN 8 AND 14 THEN '8-14'
        WHEN lead_days BETWEEN 15 AND 30 THEN '15-30'
        WHEN lead_days >= 31 THEN '31+'
    END AS lead_band,
    COUNT(*) AS appointments,
    SUM(no_show) AS no_shows,
    ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments
WHERE lead_days >= 1
GROUP BY lead_band
ORDER BY MIN(lead_days);

-- =========================================================
-- Task 2.4 — Month-by-month trend
-- =========================================================

WITH monthly AS (
    SELECT
        SUBSTR(appt_date, 1, 7) AS month,
        COUNT(*) AS appointments,
        ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
    FROM appointments
    GROUP BY SUBSTR(appt_date, 1, 7)
)
SELECT
    month,
    appointments,
    no_show_pct,
    ROUND(
        no_show_pct - LAG(no_show_pct) OVER (ORDER BY month),
        1
    ) AS change_percentage_points
FROM monthly
ORDER BY month;

-- =========================================================
-- Task 2.5 — Rank clinics within each city
-- Uses scalar subqueries for comparison with the overall no-show rate,
-- as specified in the assignment brief.
-- =========================================================

WITH clinic_rates AS (
    SELECT
        c.clinic_name AS clinic,
        c.city,
        ROUND(
            100.0 * SUM(a.no_show) / COUNT(*),
            1
        ) AS no_show_pct
    FROM appointments AS a
    JOIN clinics AS c
        ON c.clinic_id = a.clinic_id
    GROUP BY
        c.clinic_name,
        c.city
)
SELECT
    clinic,
    city,
    no_show_pct,
    RANK() OVER (
        PARTITION BY city
        ORDER BY no_show_pct DESC
    ) AS rank_in_city,
    CASE
        WHEN no_show_pct > (
            SELECT 100.0 * SUM(no_show) / COUNT(*)
            FROM appointments
        ) THEN 'above'
        WHEN no_show_pct < (
            SELECT 100.0 * SUM(no_show) / COUNT(*)
            FROM appointments
        ) THEN 'below'
        ELSE 'equal'
    END AS vs_overall
FROM clinic_rates
ORDER BY
    city,
    rank_in_city;
