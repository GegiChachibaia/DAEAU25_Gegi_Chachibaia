----------------------------------------------------
-- task 1 
----------------------------------------------------

CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category_name,
    SUM(p.amount) AS total_revenue
FROM payment p
JOIN rental r ON p.rental_id = r.rental_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
WHERE 
    EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY c.name
HAVING SUM(p.amount) > 0;


----------------------------------------------------
-- task 2
----------------------------------------------------
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(
    pqtr text   
)
RETURNS TABLE (
    category_name text,
    total_revenue numeric
)
LANGUAGE sql
AS $$
    WITH parsed AS (
        SELECT 
            split_part(pqtr, '-', 1)::int AS yr,
            replace(split_part(pqtr, '-', 2), 'Q', '')::int AS qr
    )
    SELECT 
        c.name AS category_name,
        SUM(p.amount) AS total_revenue
    FROM payment p
    JOIN rental r ON p.rental_id = r.rental_id
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film f ON i.film_id = f.film_id
    JOIN film_category fc ON f.film_id = fc.film_id
    JOIN category c ON fc.category_id = c.category_id
    CROSS JOIN parsed pz
    WHERE
        EXTRACT(YEAR FROM p.payment_date) = pz.yr
        AND EXTRACT(QUARTER FROM p.payment_date) = pz.qr
    GROUP BY c.name
    HAVING SUM(p.amount) > 0;
$$;

----------------------------------------------------
-- task 3
----------------------------------------------------
CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(
    p_countries text[]
)
RETURNS TABLE (
    country_name text,
    film_title text,
    film_rating text,
    film_language text,
    film_length int,
    release_year int
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_countries IS NULL OR array_length(p_countries, 1) = 0 THEN
        RAISE EXCEPTION 'Country array cannot be empty';
    END IF;

    RETURN QUERY
    WITH country_customers AS (
        SELECT 
            c.country_id,
            c.country AS country_name,
            cu.customer_id
        FROM country c
        JOIN city ci ON c.country_id = ci.country_id
        JOIN address a ON ci.city_id = a.city_id
        JOIN customer cu ON cu.address_id = a.address_id
        WHERE c.country = ANY(p_countries)
    ),
    film_popularity AS (
        SELECT 
            cc.country_name,
            f.film_id,
            COUNT(*) AS rental_count
        FROM country_customers cc
        JOIN rental r ON cc.customer_id = r.customer_id
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON i.film_id = f.film_id
        GROUP BY cc.country_name, f.film_id
    ),
    most_popular AS (
        SELECT DISTINCT ON (country_name)
            country_name,
            film_id,
            rental_count
        FROM film_popularity
        ORDER BY country_name, rental_count DESC
    )
    SELECT 
        mp.country_name,
        f.title AS film_title,
        f.rating AS film_rating,
        l.name AS film_language,
        f.length AS film_length,
        f.release_year
    FROM most_popular mp
    JOIN film f ON mp.film_id = f.film_id
    JOIN language l ON f.language_id = l.language_id
    ORDER BY mp.country_name;

END;
$$;

------------------------------------------------
-- task 4
------------------------------------------------

CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(
    p_title_pattern text
)
RETURNS TABLE (
    row_num int,
    film_title text,
    film_language text,
    customer_name text,
    rental_date timestamp
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate input
    IF p_title_pattern IS NULL OR p_title_pattern = '' THEN
        RAISE EXCEPTION 'Title pattern cannot be empty';
    END IF;

    RETURN QUERY
    WITH matched_films AS (
        SELECT 
            f.film_id,
            f.title,
            l.name AS language_name
        FROM film f
        JOIN language l ON f.language_id = l.language_id
        WHERE f.title ILIKE p_title_pattern
    ),
    last_rentals AS (
        SELECT 
            m.film_id,
            r.customer_id,
            r.rental_date,
            ROW_NUMBER() OVER (
                PARTITION BY m.film_id 
                ORDER BY r.rental_date DESC
            ) AS rn
        FROM matched_films m
        JOIN inventory i ON m.film_id = i.film_id
        JOIN rental r ON i.inventory_id = r.inventory_id
    ),
    enriched AS (
        SELECT 
            m.title AS film_title,
            m.language_name AS film_language,
            (cu.first_name || ' ' || cu.last_name) AS customer_name,
            lr.rental_date
        FROM matched_films m
        JOIN last_rentals lr ON m.film_id = lr.film_id AND lr.rn = 1
        JOIN customer cu ON lr.customer_id = cu.customer_id
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY film_title) AS row_num,
        film_title,
        film_language,
        customer_name,
        rental_date
    FROM enriched;

    -- If nothing was returned, notify user (but do not error)
    IF NOT FOUND THEN
        RAISE NOTICE 'No films found in stock matching pattern: %', p_title_pattern;
    END IF;

END;
$$;

------------------------------------------------
-- task 5
------------------------------------------------

CREATE OR REPLACE FUNCTION core.new_movie(
    p_title text,
    p_release_year int DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language text DEFAULT 'Klingon'
)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id int;
    v_existing_film_id int;
BEGIN
    -- Validate title
    IF p_title IS NULL OR LENGTH(TRIM(p_title)) = 0 THEN
        RAISE EXCEPTION 'Movie title cannot be empty';
    END IF;

    -- Validate that the language exists
    SELECT language_id
    INTO v_language_id
    FROM language
    WHERE name = p_language;

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist in the language table', p_language;
    END IF;

    -- Check if the film already exists
    SELECT film_id
    INTO v_existing_film_id
    FROM film
    WHERE title = p_title;

    IF v_existing_film_id IS NOT NULL THEN
        -- Replace (update) the existing film
        UPDATE film
        SET 
            language_id = v_language_id,
            rental_duration = 3,
            rental_rate = 4.99,
            replacement_cost = 19.99,
            release_year = p_release_year,
            last_update = CURRENT_TIMESTAMP
        WHERE film_id = v_existing_film_id;

        RETURN format('Movie "%" updated successfully (film_id = %)', p_title, v_existing_film_id);
    END IF;

    -- Insert new movie
    INSERT INTO film (
        title, language_id, rental_duration, rental_rate,
        replacement_cost, release_year, last_update
    )
    VALUES (
        p_title, v_language_id, 3, 4.99,
        19.99, p_release_year, CURRENT_TIMESTAMP
    )
    RETURNING film_id INTO v_existing_film_id;

    RETURN format('New movie "%" inserted successfully (film_id = %)', p_title, v_existing_film_id);
END;
$$;


