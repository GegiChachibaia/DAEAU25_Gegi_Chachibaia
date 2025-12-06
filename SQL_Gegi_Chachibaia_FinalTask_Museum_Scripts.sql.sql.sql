/* ============================================================================
   0. CREATE SCHEMA
   ============================================================================ */

DROP SCHEMA IF EXISTS museum_schema CASCADE;
CREATE SCHEMA museum_schema;
SET search_path TO museum_schema;


/* ============================================================================
   1. TABLE DEFINITIONS (DDL)
   ============================================================================ */

-----------------------------------------------------
-- EMPLOYEE
-----------------------------------------------------
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    salary NUMERIC(10,2) NOT NULL
);

-----------------------------------------------------
-- VISITOR
-----------------------------------------------------
CREATE TABLE visitor (
    visitor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(150) NOT NULL,
    phone_number VARCHAR(25)
);

-----------------------------------------------------
-- EXHIBITION
-----------------------------------------------------
CREATE TABLE exhibition (
    exhibition_id SERIAL PRIMARY KEY,
    title VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    supervisor_id INT NOT NULL REFERENCES employee(employee_id)
);

-----------------------------------------------------
-- ARTIST
-----------------------------------------------------
CREATE TABLE artist (
    artist_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_year INT,
    nationality VARCHAR(50)
);

-----------------------------------------------------
-- ARTIFACT
-----------------------------------------------------
CREATE TABLE artifact (
    artifact_id SERIAL PRIMARY KEY,
    artifact_name VARCHAR(50) NOT NULL,
    description TEXT,
    creation_year INT,
    exhibition_id INT REFERENCES exhibition(exhibition_id),
    caretaker_id INT REFERENCES employee(employee_id)
);

-----------------------------------------------------
-- TICKET (Transactions)
-----------------------------------------------------
CREATE TABLE ticket (
    ticket_id SERIAL PRIMARY KEY,
    visitor_id INT NOT NULL REFERENCES visitor(visitor_id),
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    price NUMERIC(10,2) NOT NULL
);

-----------------------------------------------------
-- ARTIFACT_ARTIST (Many-to-Many)
-----------------------------------------------------
CREATE TABLE artifact_artist (
    artifact_id INT NOT NULL REFERENCES artifact(artifact_id),
    artist_id INT NOT NULL REFERENCES artist(artist_id),
    PRIMARY KEY (artifact_id, artist_id)
);



/* ============================================================================
   2. CHECK CONSTRAINTS
   ============================================================================ */

ALTER TABLE employee
ADD CONSTRAINT chk_salary_non_negative CHECK (salary >= 0);

ALTER TABLE employee
ADD CONSTRAINT chk_position_allowed
CHECK (position IN ('Curator','Guide','Security','Manager','Ticket clerk'));

ALTER TABLE exhibition
ADD CONSTRAINT chk_exhibition_start CHECK (start_date >= DATE '2024-01-01');

ALTER TABLE exhibition
ADD CONSTRAINT chk_exhibition_dates CHECK (end_date >= start_date);

ALTER TABLE artifact
ADD CONSTRAINT chk_artifact_year CHECK (
    creation_year IS NULL OR creation_year <= EXTRACT(YEAR FROM CURRENT_DATE)
);

ALTER TABLE artist
ADD CONSTRAINT chk_artist_birth CHECK (
    birth_year IS NULL OR birth_year <= EXTRACT(YEAR FROM CURRENT_DATE)
);

ALTER TABLE visitor
ADD CONSTRAINT uq_visitor_email UNIQUE(email);

ALTER TABLE ticket
ADD CONSTRAINT chk_ticket_price CHECK (price >= 0);



/* ============================================================================
   3. GENERATED ALWAYS AS STORED COLUMNS
   ============================================================================ */

-- Employee full name
ALTER TABLE employee
ADD COLUMN full_name TEXT
    GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED;

-- Ticket year + quarter for analytics
ALTER TABLE ticket
ADD COLUMN ticket_year INT
    GENERATED ALWAYS AS (EXTRACT(YEAR FROM purchase_date)::INT) STORED,
ADD COLUMN ticket_quarter INT
    GENERATED ALWAYS AS (EXTRACT(QUARTER FROM purchase_date)::INT) STORED;



/* ============================================================================
   4. INSERT SAMPLE DATA (6 rows minimum each)
   ============================================================================ */

-----------------------------------------------------
-- EMPLOYEE DATA
-----------------------------------------------------
INSERT INTO employee (first_name, last_name, position, hire_date, salary)
VALUES
('Anna','Smith','Curator', CURRENT_DATE - INTERVAL '70 days', 3200),
('David','Brown','Guide', CURRENT_DATE - INTERVAL '60 days', 2100),
('Maya','Jones','Security', CURRENT_DATE - INTERVAL '55 days', 1900),
('Leo','Garcia','Manager', CURRENT_DATE - INTERVAL '80 days', 4000),
('Nina','Peterson','Ticket clerk', CURRENT_DATE - INTERVAL '40 days', 1800),
('Omar','Ali','Guide', CURRENT_DATE - INTERVAL '20 days', 2200);

-----------------------------------------------------
-- VISITOR DATA
-----------------------------------------------------
INSERT INTO visitor (first_name, last_name, email, phone_number)
VALUES
('Luka','Kapanadze','luka@example.com','+995511111111'),
('Sophie','Adams','sophie@example.com','+995522222222'),
('Mark','Turner','mark@example.com','+995533333333'),
('Nika','Beridze','nika@example.com','+995544444444'),
('Elene','Giorgadze','elene@example.com','+995555555555'),
('Tom','Carter','tom@example.com','+995566666666');

-----------------------------------------------------
-- EXHIBITION DATA
-----------------------------------------------------
INSERT INTO exhibition (title, start_date, end_date, supervisor_id)
VALUES
('Impressionist Masters', CURRENT_DATE - INTERVAL '80 days', CURRENT_DATE - INTERVAL '50 days', 1),
('Ancient Sculptures', CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE - INTERVAL '30 days', 4),
('Modern Art Week', CURRENT_DATE - INTERVAL '40 days', CURRENT_DATE - INTERVAL '10 days', 1),
('Photography Stories', CURRENT_DATE - INTERVAL '35 days', CURRENT_DATE - INTERVAL '5 days', 4),
('Renaissance Sketches', CURRENT_DATE - INTERVAL '25 days', CURRENT_DATE - INTERVAL '3 days', 1),
('Street Art Pop-Up', CURRENT_DATE - INTERVAL '15 days', CURRENT_DATE + INTERVAL '10 days', 4);

-----------------------------------------------------
-- ARTIST DATA
-----------------------------------------------------
INSERT INTO artist (first_name, last_name, birth_year, nationality)
VALUES
('Claude','Monet',1840,'French'),
('Pablo','Picasso',1881,'Spanish'),
('Leonardo','da Vinci',1452,'Italian'),
('Auguste','Rodin',1840,'French'),
('Hokusai','Katsushika',1760,'Japanese'),
('Banksy','Unknown',1974,'British');

-----------------------------------------------------
-- ARTIFACT DATA
-----------------------------------------------------
INSERT INTO artifact (artifact_name, description, creation_year, exhibition_id, caretaker_id)
VALUES
('Water Lilies','Famous impressionist painting',1916,1,1),
('Ancient Greek Statue','Marble statue, 2nd century BC',-150,2,3),
('Cubist Portrait','Early cubist artwork',1909,3,1),
('Street Wall Piece','Graffiti removable panel',2018,6,6),
('Samurai Print','Traditional ukiyo-e artwork',1830,4,3),
('Renaissance Sketchbook','Historic anatomy sketches',1500,5,1);

-----------------------------------------------------
-- TICKET DATA
-----------------------------------------------------
INSERT INTO ticket (visitor_id, purchase_date, price)
VALUES
(1, CURRENT_DATE - INTERVAL '70 days', 15),
(2, CURRENT_DATE - INTERVAL '55 days', 20),
(3, CURRENT_DATE - INTERVAL '40 days', 18),
(4, CURRENT_DATE - INTERVAL '25 days', 12),
(5, CURRENT_DATE - INTERVAL '10 days', 22),
(6, CURRENT_DATE - INTERVAL '5 days', 15);

-----------------------------------------------------
-- ARTIFACT_ARTIST DATA
-----------------------------------------------------
INSERT INTO artifact_artist (artifact_id, artist_id)
VALUES
(1,1),
(2,4),
(3,2),
(4,6),
(5,5),
(6,3);



/* ============================================================================
   5. FUNCTIONS
   ============================================================================ */

-----------------------------------------------------
-- 5.1 GENERIC UPDATE FUNCTION
-----------------------------------------------------
CREATE OR REPLACE FUNCTION update_artifact_column(
    p_artifact_id INT,
    p_column_name TEXT,
    p_new_value TEXT
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    IF p_column_name NOT IN ('artifact_name','description','creation_year','caretaker_id','exhibition_id') THEN
        RAISE EXCEPTION 'Invalid column name: %', p_column_name;
    END IF;

    v_sql := format('UPDATE artifact SET %I = $1 WHERE artifact_id = $2', p_column_name);
    EXECUTE v_sql USING p_new_value, p_artifact_id;

    RAISE NOTICE 'Updated artifact % column % to %', p_artifact_id, p_column_name, p_new_value;
END;
$$;


-----------------------------------------------------
-- 5.2 ADD TICKET TRANSACTION (NATURAL KEY: visitor email)
-----------------------------------------------------
CREATE OR REPLACE FUNCTION add_ticket_transaction(
    p_visitor_email VARCHAR,
    p_price NUMERIC,
    p_purchase_date DATE DEFAULT CURRENT_DATE
) RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_visitor_id INT;
BEGIN
    SELECT visitor_id INTO v_visitor_id
    FROM visitor
    WHERE email = p_visitor_email;

    IF v_visitor_id IS NULL THEN
        RAISE EXCEPTION 'Visitor % not found', p_visitor_email;
    END IF;

    INSERT INTO ticket (visitor_id, purchase_date, price)
    VALUES (v_visitor_id, p_purchase_date, p_price);

    RAISE NOTICE 'Ticket added for visitor %, date %, price %',
        p_visitor_email, p_purchase_date, p_price;
END;
$$;



/* ============================================================================
   6. VIEW: LATEST QUARTER ANALYTICS
   ============================================================================ */

CREATE OR REPLACE VIEW v_latest_quarter_ticket_analytics AS
WITH last_q AS (
    SELECT ticket_year, ticket_quarter
    FROM ticket
    ORDER BY ticket_year DESC, ticket_quarter DESC
    LIMIT 1
)
SELECT
    v.first_name,
    v.last_name,
    v.email,
    t.ticket_year AS year,
    t.ticket_quarter AS quarter,
    COUNT(*) AS tickets_count,
    SUM(t.price) AS total_revenue,
    AVG(t.price) AS avg_ticket_price
FROM ticket t
JOIN visitor v ON v.visitor_id = t.visitor_id
JOIN last_q l ON 
    l.ticket_year = t.ticket_year
    AND l.ticket_quarter = t.ticket_quarter
GROUP BY
    v.first_name, v.last_name, v.email, t.ticket_year, t.ticket_quarter;



/* ============================================================================
   7. READ-ONLY ROLE FOR MANAGER
   ============================================================================ */

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='museum_manager') THEN
        CREATE ROLE museum_manager LOGIN PASSWORD 'ChangeMe_StrongPassword1!';
    END IF;
END $$;

GRANT CONNECT ON DATABASE museum TO museum_manager;
GRANT USAGE ON SCHEMA museum_schema TO museum_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA museum_schema TO museum_manager;

ALTER DEFAULT PRIVILEGES IN SCHEMA museum_schema
GRANT SELECT ON TABLES TO museum_manager;

