------------------------------------------------------------
-- TASK 1: Create user "rentaluser" with password
------------------------------------------------------------
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';

GRANT CONNECT ON DATABASE dvdrental TO rentaluser;


------------------------------------------------------------
-- TASK 2: Grant SELECT on customer table
------------------------------------------------------------
GRANT SELECT ON TABLE public.customer TO rentaluser;

SET ROLE rentaluser;
SELECT * FROM public.customer LIMIT 5;
RESET ROLE;


------------------------------------------------------------
-- TASK 3: Create role "rental" group and add rentaluser
------------------------------------------------------------
CREATE ROLE rental;
GRANT rental TO rentaluser;


------------------------------------------------------------
-- TASK 4: Grant INSERT + UPDATE to rental group
------------------------------------------------------------
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;
GRANT INSERT, UPDATE ON TABLE public.rental TO rentaluser;

-- Sequence permissions
GRANT USAGE, SELECT, UPDATE ON SEQUENCE public.rental_rental_id_seq TO rental;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE public.rental_rental_id_seq TO rentaluser;

-- Ensure inheritance is enabled
ALTER ROLE rental INHERIT;
ALTER ROLE rentaluser INHERIT;


------------------------------------------------------------
-- TASK 5: Test INSERT + UPDATE as rentaluser
------------------------------------------------------------
SET ROLE rentaluser;

INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);

UPDATE public.rental
SET return_date = NOW()
WHERE rental_id = 1;

RESET ROLE;


------------------------------------------------------------
-- TASK 6: Revoke INSERT from group rental
------------------------------------------------------------
REVOKE INSERT ON TABLE public.rental FROM rental;


------------------------------------------------------------
-- TASK 7: Test INSERT is now denied
------------------------------------------------------------
SET ROLE rentaluser;

-- This MUST FAIL:
INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);

RESET ROLE;


------------------------------------------------------------
-- TASK 8: Create personalized role for real customer
------------------------------------------------------------

SELECT c.customer_id, c.first_name, c.last_name
FROM public.customer c
JOIN public.rental r ON r.customer_id = c.customer_id
JOIN public.payment p ON p.customer_id = c.customer_id
WHERE c.customer_id = 2
GROUP BY c.customer_id, c.first_name, c.last_name;

DROP ROLE IF EXISTS client_gegi_chachibaia;

CREATE ROLE client_gegi_chachibaia
    LOGIN
    PASSWORD 'ClientPassword123'
    INHERIT;

GRANT CONNECT ON DATABASE dvd_rental TO client_gegi_chachibaia;
GRANT USAGE ON SCHEMA public TO client_gegi_chachibaia;

GRANT SELECT ON TABLE public.customer TO client_gegi_chachibaia;
GRANT SELECT ON TABLE public.rental TO client_gegi_chachibaia;
GRANT SELECT ON TABLE public.payment TO client_gegi_chachibaia;


------------------------------------------------------------
-- TASK 9: Implement Row-Level Security (RLS)
------------------------------------------------------------

-- Enable RLS on rental and payment tables
ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Remove default permissive behavior
ALTER TABLE public.rental FORCE ROW LEVEL SECURITY;
ALTER TABLE public.payment FORCE ROW LEVEL SECURITY;


------------------------------------------------------------
-- Create RLS Policies so customer sees only their data
------------------------------------------------------------

-- Rental table RLS
DROP POLICY IF EXISTS rental_policy_gegi ON public.rental;

CREATE POLICY rental_policy_gegi
    ON public.rental
    FOR SELECT
    TO client_gegi_chachibaia
    USING (customer_id = 2);


-- Payment table RLS
DROP POLICY IF EXISTS payment_policy_gegi ON public.payment;

CREATE POLICY payment_policy_gegi
    ON public.payment
    FOR SELECT
    TO client_gegi_chachibaia
    USING (customer_id = 2);


------------------------------------------------------------
-- TASK 10: Test RLS
------------------------------------------------------------
SET ROLE client_gegi_chachibaia;

SELECT 
    payment_id,
    customer_id,
    staff_id,
    rental_id,
    amount,
    payment_date
FROM public.payment;

SELECT 
    rental_id,
    rental_date,
    inventory_id,
    customer_id,
    return_date,
    staff_id,
    last_update
FROM public.rental;


RESET ROLE;


