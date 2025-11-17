--------------------------------------------------------------------
-- 0. DATABASE & SCHEMA (run CREATE DATABASE manually if needed)
--------------------------------------------------------------------
-- CREATE DATABASE metro_management;
-- \c metro_management;

DROP SCHEMA IF EXISTS metro CASCADE;      -- makes script rerunnable
CREATE SCHEMA metro;
SET search_path TO metro;

--------------------------------------------------------------------
-- 1. ROOT TABLES (no FK dependencies)
--------------------------------------------------------------------

-------------------------
-- 1.1 Stations
-------------------------
CREATE TABLE stations (
    station_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- auto increment
    previous_station_id INT,                                           -- self-reference, nullable
    station_name        VARCHAR(50)  NOT NULL,
    is_underground      BOOLEAN      NOT NULL DEFAULT TRUE,
    open_date           DATE,
    platform_count      INT          NOT NULL CHECK (platform_count > 0), -- measured value > 0
    entrance_count      INT          NOT NULL CHECK (entrance_count > 0),
    status              VARCHAR(20)  NOT NULL DEFAULT 'Active',
    manager_id          INT          NOT NULL UNIQUE,    -- unique manager per station
    city                VARCHAR(50)  NOT NULL
);

-- self-FK for previous station
ALTER TABLE stations
ADD CONSTRAINT fk_stations_previous
FOREIGN KEY (previous_station_id)
REFERENCES stations(station_id);

-------------------------
-- 1.2 Metro_Line
-------------------------
CREATE TABLE metro_line (
    line_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    line_name      VARCHAR(50) NOT NULL UNIQUE,
    total_stations INT         NOT NULL CHECK (total_stations >= 2), -- at least 2 stations per line
    start_time     TIME        NOT NULL,
    end_time       TIME        NOT NULL,
    open_date      DATE        NOT NULL CHECK (open_date > DATE '2000-01-01'), -- date > 2000-01-01
    status         VARCHAR(20) NOT NULL DEFAULT 'Active'
);

-------------------------
-- 1.3 Role
-------------------------
CREATE TABLE role (
    role_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name    VARCHAR(50)   NOT NULL,
    department   VARCHAR(50)   NOT NULL,
    base_salary  DECIMAL(6,2)  NOT NULL CHECK (base_salary >= 0), -- non-negative
    is_active    BOOLEAN       NOT NULL DEFAULT TRUE,
    description  VARCHAR(1000) NOT NULL
);

-------------------------
-- 1.4 Passenger
-------------------------
CREATE TABLE passenger (
    passenger_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(30)  NOT NULL,
    last_name     VARCHAR(40)  NOT NULL,
    email         VARCHAR(100) NOT NULL
                  CHECK (email ILIKE '%@gmail.com' OR email ILIKE '%@yahoo.com'),
    birth_date    DATE         NOT NULL CHECK (birth_date > DATE '1950-01-01'),
    gender        VARCHAR(6)   NOT NULL
                  CHECK (gender IN ('Male','Female','Other')),       -- restricted set
    phone_number  VARCHAR(13)  NOT NULL,
    city          VARCHAR(30)  NOT NULL,
    register_date DATE         NOT NULL CHECK (register_date > DATE '2000-01-01')
);

--------------------------------------------------------------------
-- 2. TABLES WITH SIMPLE FKs
--------------------------------------------------------------------

-------------------------
-- 2.1 Route
-------------------------
CREATE TABLE route (
    route_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_name       VARCHAR(50) NOT NULL UNIQUE,
    line_id          INT         NOT NULL,
    start_station_id INT         NOT NULL,
    end_station_id   INT         NOT NULL,
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_route_line
        FOREIGN KEY (line_id) REFERENCES metro_line(line_id),
    CONSTRAINT fk_route_start_station
        FOREIGN KEY (start_station_id) REFERENCES stations(station_id),
    CONSTRAINT fk_route_end_station
        FOREIGN KEY (end_station_id)   REFERENCES stations(station_id)
);

-------------------------
-- 2.2 Tunnel
-------------------------
CREATE TABLE tunnel (
    tunnel_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tunnel_name     VARCHAR(50) NOT NULL,
    start_station_id INT        NOT NULL,
    end_station_id   INT        NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_tunnel_start_station
        FOREIGN KEY (start_station_id) REFERENCES stations(station_id),
    CONSTRAINT fk_tunnel_end_station
        FOREIGN KEY (end_station_id)   REFERENCES stations(station_id)
);

-------------------------
-- 2.3 Train
-------------------------
CREATE TABLE train (
    train_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    train_name         VARCHAR(50) NOT NULL,
    line_id            INT         NOT NULL,
    capacity           INT         NOT NULL CHECK (capacity > 0),
    model              VARCHAR(50) NOT NULL,
    manufacturer       VARCHAR(50) NOT NULL,
    manufacture_year   INT         NOT NULL CHECK (manufacture_year >= 1990),
    service_start_date DATE        NOT NULL CHECK (service_start_date > DATE '2000-01-01'),
    maintenance_date   DATE,
    status             VARCHAR(20) NOT NULL DEFAULT 'Active',
    wagon_count        INT         NOT NULL CHECK (wagon_count > 0),
    CONSTRAINT fk_train_line
        FOREIGN KEY (line_id) REFERENCES metro_line(line_id)
);

--------------------------------------------------------------------
-- 3. EMPLOYEE & BRIDGE TABLES
--------------------------------------------------------------------

-------------------------
-- 3.1 Employee
-------------------------
CREATE TABLE employee (
    employee_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    phone_number  VARCHAR(13)  NOT NULL,
    email         VARCHAR(100) NOT NULL
                  CHECK (email ILIKE '%@gmail.com' OR email ILIKE '%@yahoo.com'),
    hire_date     DATE         NOT NULL CHECK (hire_date > DATE '2000-01-01'),
    salary        DECIMAL(6,2) NOT NULL CHECK (salary >= 0),
    role_id       INT          NOT NULL,
    station_id    INT          NOT NULL,
    supervisor_id INT,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_employee_role
        FOREIGN KEY (role_id)    REFERENCES role(role_id),
    CONSTRAINT fk_employee_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-- self-reference for supervisor
ALTER TABLE employee
ADD CONSTRAINT fk_employee_supervisor
FOREIGN KEY (supervisor_id) REFERENCES employee(employee_id);

-------------------------
-- 3.2 Station_Line (many-to-many between line and station)
-------------------------
CREATE TABLE station_line (
    station_line_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    line_id         INT NOT NULL,
    station_id      INT NOT NULL,
    CONSTRAINT fk_station_line_line
        FOREIGN KEY (line_id)   REFERENCES metro_line(line_id),
    CONSTRAINT fk_station_line_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id),
    CONSTRAINT uq_station_line UNIQUE (line_id, station_id)
);

-------------------------
-- 3.3 StationEmployee (extra assignment table)
-------------------------
CREATE TABLE stationemployee (
    stationemployeeid INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employeeid        INT NOT NULL,
    stationid         INT NOT NULL,
    CONSTRAINT fk_stationemployee_employee
        FOREIGN KEY (employeeid) REFERENCES employee(employee_id),
    CONSTRAINT fk_stationemployee_station
        FOREIGN KEY (stationid)  REFERENCES stations(station_id),
    CONSTRAINT uq_stationemployee UNIQUE (employeeid, stationid)
);

--------------------------------------------------------------------
-- 4. PAYMENT & TICKETING
--------------------------------------------------------------------

-------------------------
-- 4.1 Payment
-------------------------
CREATE TABLE payment (
    payment_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    passenger_id   INT         NOT NULL,
    payment_method VARCHAR(4)  NOT NULL
                   CHECK (payment_method IN ('cash','card')),
    payment_date   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount         DECIMAL(4,2) NOT NULL CHECK (amount >= 0),   -- measured value >= 0
    provider_name  VARCHAR(50),
    CONSTRAINT fk_payment_passenger
        FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id)
);

-------------------------
-- 4.2 Ticket
-------------------------
CREATE TABLE ticket (
    ticket_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id     INT        NOT NULL,
    station_id     INT        NOT NULL,
    purchase_date  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    price          DECIMAL(4,2) NOT NULL CHECK (price >= 0),
    is_used        BOOLEAN    NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_ticket_payment
        FOREIGN KEY (payment_id) REFERENCES payment(payment_id),
    CONSTRAINT fk_ticket_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

--------------------------------------------------------------------
-- 5. SCHEDULE & MAINTENANCE
--------------------------------------------------------------------

-------------------------
-- 5.1 Schedule
-------------------------
CREATE TABLE schedule (
    schedule_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    train_id       INT      NOT NULL,
    route_id       INT      NOT NULL,
    station_id     INT      NOT NULL,
    arrival_time   TIME     NOT NULL,
    departure_time TIME     NOT NULL,
    is_active      BOOLEAN  NOT NULL DEFAULT TRUE,
    effective_from DATE     NOT NULL CHECK (effective_from > DATE '2000-01-01'),
    effective_to   DATE     CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT fk_schedule_train
        FOREIGN KEY (train_id)   REFERENCES train(train_id),
    CONSTRAINT fk_schedule_route
        FOREIGN KEY (route_id)   REFERENCES route(route_id),
    CONSTRAINT fk_schedule_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

-------------------------
-- 5.2 Maintenance_Record
-------------------------
CREATE TABLE maintenance_record (
    maintenance_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    train_id         INT         NOT NULL,
    station_id       INT         NOT NULL,
    tunnel_id        INT         NOT NULL,
    employee_id      INT         NOT NULL,
    maintenance_type VARCHAR(1000) NOT NULL,
    start_time       TIMESTAMP,
    end_time         TIMESTAMP   NOT NULL,
    status           VARCHAR(40) NOT NULL,
    cost             DECIMAL(10,2) NOT NULL CHECK (cost >= 0),
    CONSTRAINT fk_maint_train
        FOREIGN KEY (train_id)   REFERENCES train(train_id),
    CONSTRAINT fk_maint_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id),
    CONSTRAINT fk_maint_tunnel
        FOREIGN KEY (tunnel_id)  REFERENCES tunnel(tunnel_id),
    CONSTRAINT fk_maint_employee
        FOREIGN KEY (employee_id) REFERENCES employee(employee_id),
    CONSTRAINT chk_maint_time CHECK (start_time IS NULL OR end_time > start_time)
);

--------------------------------------------------------------------
-- 6. SAMPLE DATA (>= 2 rows per table, no duplicates)
--    Using WHERE NOT EXISTS to keep script rerunnable.
--------------------------------------------------------------------

-------------------------
-- 6.1 Stations
-------------------------
INSERT INTO stations (previous_station_id, station_name, is_underground,
                      open_date, platform_count, entrance_count,
                      status, manager_id, city)
SELECT NULL, 'Central', TRUE, DATE '2010-01-01', 4, 6, 'Active', 1001, 'Tbilisi'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'Central');

INSERT INTO stations (previous_station_id, station_name, is_underground,
                      open_date, platform_count, entrance_count,
                      status, manager_id, city)
SELECT 1, 'Airport', FALSE, DATE '2015-05-01', 2, 3, 'Active', 1002, 'Tbilisi'
WHERE NOT EXISTS (SELECT 1 FROM stations WHERE station_name = 'Airport');

-------------------------
-- 6.2 Metro lines
-------------------------
INSERT INTO metro_line (line_name, total_stations, start_time, end_time, open_date, status)
SELECT 'Red Line', 10, TIME '06:00', TIME '23:00', DATE '2010-01-01', 'Active'
WHERE NOT EXISTS (SELECT 1 FROM metro_line WHERE line_name = 'Red Line');

INSERT INTO metro_line (line_name, total_stations, start_time, end_time, open_date, status)
SELECT 'Blue Line', 8, TIME '06:30', TIME '22:30', DATE '2012-06-01', 'Active'
WHERE NOT EXISTS (SELECT 1 FROM metro_line WHERE line_name = 'Blue Line');

-------------------------
-- 6.3 Roles
-------------------------
INSERT INTO role (role_name, department, base_salary, is_active, description)
SELECT 'Driver', 'Operations', 1500.00, TRUE, 'Train driver'
WHERE NOT EXISTS (SELECT 1 FROM role WHERE role_name = 'Driver');

INSERT INTO role (role_name, department, base_salary, is_active, description)
SELECT 'Mechanic', 'Maintenance', 1400.00, TRUE, 'Rolling stock mechanic'
WHERE NOT EXISTS (SELECT 1 FROM role WHERE role_name = 'Mechanic');

-------------------------
-- 6.4 Passengers
-------------------------
INSERT INTO passenger (first_name, last_name, email, birth_date, gender,
                       phone_number, city, register_date)
SELECT 'Nika','Beridze','nika@gmail.com', DATE '1998-03-02','Male',
       '+995599000001','Tbilisi', DATE '2024-01-01'
WHERE NOT EXISTS (SELECT 1 FROM passenger WHERE email = 'nika@gmail.com');

INSERT INTO passenger (first_name, last_name, email, birth_date, gender,
                       phone_number, city, register_date)
SELECT 'Ana','Kobalia','ana@yahoo.com', DATE '2000-07-15','Female',
       '+995599000002','Tbilisi', DATE '2024-02-10'
WHERE NOT EXISTS (SELECT 1 FROM passenger WHERE email = 'ana@yahoo.com');

-------------------------
-- 6.5 Routes
-------------------------
INSERT INTO route (route_name, line_id, start_station_id, end_station_id, is_active)
SELECT 'Central-Airport', ml.line_id, s1.station_id, s2.station_id, TRUE
FROM metro_line ml
JOIN stations s1 ON ml.line_name = 'Red Line' AND s1.station_name = 'Central'
JOIN stations s2 ON s2.station_name = 'Airport'
WHERE NOT EXISTS (SELECT 1 FROM route WHERE route_name = 'Central-Airport');

INSERT INTO route (route_name, line_id, start_station_id, end_station_id, is_active)
SELECT 'Airport-Central', ml.line_id, s2.station_id, s1.station_id, TRUE
FROM metro_line ml
JOIN stations s1 ON ml.line_name = 'Red Line' AND s1.station_name = 'Central'
JOIN stations s2 ON s2.station_name = 'Airport'
WHERE NOT EXISTS (SELECT 1 FROM route WHERE route_name = 'Airport-Central');

-------------------------
-- 6.6 Tunnels
-------------------------
INSERT INTO tunnel (tunnel_name, start_station_id, end_station_id, status)
SELECT 'Central-Airport Tunnel', s1.station_id, s2.station_id, 'Active'
FROM stations s1, stations s2
WHERE s1.station_name = 'Central'
  AND s2.station_name = 'Airport'
  AND NOT EXISTS (SELECT 1 FROM tunnel WHERE tunnel_name = 'Central-Airport Tunnel');

INSERT INTO tunnel (tunnel_name, start_station_id, end_station_id, status)
SELECT 'Airport-Central Tunnel', s2.station_id, s1.station_id, 'Active'
FROM stations s1, stations s2
WHERE s1.station_name = 'Central'
  AND s2.station_name = 'Airport'
  AND NOT EXISTS (SELECT 1 FROM tunnel WHERE tunnel_name = 'Airport-Central Tunnel');

-------------------------
-- 6.7 Trains
-------------------------
INSERT INTO train (train_name, line_id, capacity, model, manufacturer,
                   manufacture_year, service_start_date, maintenance_date,
                   status, wagon_count)
SELECT 'T-101', ml.line_id, 600, 'Metro3000', 'Hyundai Rotem',
       2012, DATE '2013-01-01', NULL, 'Active', 6
FROM metro_line ml
WHERE ml.line_name = 'Red Line'
  AND NOT EXISTS (SELECT 1 FROM train WHERE train_name = 'T-101');

INSERT INTO train (train_name, line_id, capacity, model, manufacturer,
                   manufacture_year, service_start_date, maintenance_date,
                   status, wagon_count)
SELECT 'T-201', ml.line_id, 500, 'Metro2500', 'CAF',
       2014, DATE '2015-03-01', NULL, 'Active', 5
FROM metro_line ml
WHERE ml.line_name = 'Blue Line'
  AND NOT EXISTS (SELECT 1 FROM train WHERE train_name = 'T-201');

-------------------------
-- 6.8 Station_Line
-------------------------
INSERT INTO station_line (line_id, station_id)
SELECT ml.line_id, s.station_id
FROM metro_line ml
JOIN stations s ON ml.line_name = 'Red Line'
WHERE s.station_name IN ('Central','Airport')
  AND NOT EXISTS (
      SELECT 1 FROM station_line sl
      WHERE sl.line_id = ml.line_id AND sl.station_id = s.station_id
  );

-------------------------
-- 6.9 Employees
-------------------------
INSERT INTO employee (first_name,last_name,phone_number,email,
                      hire_date,salary,role_id,station_id,supervisor_id,is_active)
SELECT 'Giorgi','Metreveli','+995599100001','giorgi.driver@gmail.com',
       DATE '2018-04-01',1700.00,
       r.role_id, s.station_id, NULL, TRUE
FROM role r
JOIN stations s ON s.station_name = 'Central'
WHERE r.role_name = 'Driver'
  AND NOT EXISTS (SELECT 1 FROM employee WHERE email = 'giorgi.driver@gmail.com');

INSERT INTO employee (first_name,last_name,phone_number,email,
                      hire_date,salary,role_id,station_id,supervisor_id,is_active)
SELECT 'Luka','Chkheidze','+995599100002','luka.mech@gmail.com',
       DATE '2019-06-01',1600.00,
       r.role_id, s.station_id, e.employee_id, TRUE
FROM role r
JOIN stations s ON s.station_name = 'Airport'
JOIN employee e ON e.email = 'giorgi.driver@gmail.com'
WHERE r.role_name = 'Mechanic'
  AND NOT EXISTS (SELECT 1 FROM employee WHERE email = 'luka.mech@gmail.com');

-------------------------
-- 6.10 StationEmployee
-------------------------
INSERT INTO stationemployee (employeeid, stationid)
SELECT e.employee_id, s.station_id
FROM employee e
JOIN stations s ON s.station_name = 'Central'
WHERE e.email = 'giorgi.driver@gmail.com'
  AND NOT EXISTS (
      SELECT 1 FROM stationemployee se
      WHERE se.employeeid = e.employee_id AND se.stationid = s.station_id
  );

INSERT INTO stationemployee (employeeid, stationid)
SELECT e.employee_id, s.station_id
FROM employee e
JOIN stations s ON s.station_name = 'Airport'
WHERE e.email = 'luka.mech@gmail.com'
  AND NOT EXISTS (
      SELECT 1 FROM stationemployee se
      WHERE se.employeeid = e.employee_id AND se.stationid = s.station_id
  );

-------------------------
-- 6.11 Payments
-------------------------
INSERT INTO payment (passenger_id, payment_method, amount, provider_name)
SELECT p.passenger_id, 'cash', 2.50, 'Station Cashier'
FROM passenger p
WHERE p.email = 'nika@gmail.com'
  AND NOT EXISTS (SELECT 1 FROM payment pay
                  WHERE pay.passenger_id = p.passenger_id AND pay.amount = 2.50);

INSERT INTO payment (passenger_id, payment_method, amount, provider_name)
SELECT p.passenger_id, 'card', 3.00, 'Online App'
FROM passenger p
WHERE p.email = 'ana@yahoo.com'
  AND NOT EXISTS (SELECT 1 FROM payment pay
                  WHERE pay.passenger_id = p.passenger_id AND pay.amount = 3.00);

-------------------------
-- 6.12 Tickets
-------------------------
INSERT INTO ticket (payment_id, station_id, price, is_used)
SELECT pay.payment_id, s.station_id, 2.50, TRUE
FROM payment pay
JOIN passenger p ON p.passenger_id = pay.passenger_id AND p.email = 'nika@gmail.com'
JOIN stations s ON s.station_name = 'Central'
WHERE NOT EXISTS (SELECT 1 FROM ticket t WHERE t.payment_id = pay.payment_id);

INSERT INTO ticket (payment_id, station_id, price, is_used)
SELECT pay.payment_id, s.station_id, 3.00, FALSE
FROM payment pay
JOIN passenger p ON p.passenger_id = pay.passenger_id AND p.email = 'ana@yahoo.com'
JOIN stations s ON s.station_name = 'Airport'
WHERE NOT EXISTS (SELECT 1 FROM ticket t WHERE t.payment_id = pay.payment_id);

-------------------------
-- 6.13 Schedule
-------------------------
INSERT INTO schedule (train_id, route_id, station_id,
                      arrival_time, departure_time,
                      is_active, effective_from, effective_to)
SELECT tr.train_id, r.route_id, s.station_id,
       TIME '08:00', TIME '08:05',
       TRUE, DATE '2024-01-01', NULL
FROM train tr
JOIN route r   ON r.route_name = 'Central-Airport'
JOIN stations s ON s.station_name = 'Central'
WHERE tr.train_name = 'T-101'
  AND NOT EXISTS (SELECT 1 FROM schedule sc
                  WHERE sc.train_id = tr.train_id
                    AND sc.route_id = r.route_id
                    AND sc.station_id = s.station_id);

INSERT INTO schedule (train_id, route_id, station_id,
                      arrival_time, departure_time,
                      is_active, effective_from, effective_to)
SELECT tr.train_id, r.route_id, s.station_id,
       TIME '08:25', TIME '08:30',
       TRUE, DATE '2024-01-01', NULL
FROM train tr
JOIN route r   ON r.route_name = 'Airport-Central'
JOIN stations s ON s.station_name = 'Airport'
WHERE tr.train_name = 'T-101'
  AND NOT EXISTS (SELECT 1 FROM schedule sc
                  WHERE sc.train_id = tr.train_id
                    AND sc.route_id = r.route_id
                    AND sc.station_id = s.station_id);

-------------------------
-- 6.14 Maintenance records
-------------------------
INSERT INTO maintenance_record (train_id, station_id, tunnel_id, employee_id,
                                maintenance_type, start_time, end_time,
                                status, cost)
SELECT tr.train_id, s.station_id, t.tunnel_id, e.employee_id,
       'Monthly inspection', TIMESTAMP '2024-02-01 01:00',
       TIMESTAMP '2024-02-01 03:00', 'Completed', 200.00
FROM train tr
JOIN stations s ON s.station_name = 'Central'
JOIN tunnel t   ON t.tunnel_name = 'Central-Airport Tunnel'
JOIN employee e ON e.email = 'luka.mech@gmail.com'
WHERE tr.train_name = 'T-101'
  AND NOT EXISTS (SELECT 1 FROM maintenance_record mr
                  WHERE mr.train_id = tr.train_id
                    AND mr.start_time = TIMESTAMP '2024-02-01 01:00');

INSERT INTO maintenance_record (train_id, station_id, tunnel_id, employee_id,
                                maintenance_type, start_time, end_time,
                                status, cost)
SELECT tr.train_id, s.station_id, t.tunnel_id, e.employee_id,
       'Tunnel inspection', TIMESTAMP '2024-03-01 02:00',
       TIMESTAMP '2024-03-01 04:30', 'Completed', 350.00
FROM train tr
JOIN stations s ON s.station_name = 'Airport'
JOIN tunnel t   ON t.tunnel_name = 'Airport-Central Tunnel'
JOIN employee e ON e.email = 'luka.mech@gmail.com'
WHERE tr.train_name = 'T-201'
  AND NOT EXISTS (SELECT 1 FROM maintenance_record mr
                  WHERE mr.train_id = tr.train_id
                    AND mr.start_time = TIMESTAMP '2024-03-01 02:00');

--------------------------------------------------------------------
-- 7. ADD record_ts COLUMN TO EACH TABLE
--    (NOT NULL with DEFAULT current_date)
--------------------------------------------------------------------

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'metro'
          AND table_type = 'BASE TABLE'
    LOOP
        -- add column only if it does not exist
        EXECUTE format(
            'ALTER TABLE metro.%I
             ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;',
            tbl
        );
    END LOOP;
END$$;

-- Done. You can SELECT * from tables to verify data and record_ts.

SELECT train_id FROM train;
