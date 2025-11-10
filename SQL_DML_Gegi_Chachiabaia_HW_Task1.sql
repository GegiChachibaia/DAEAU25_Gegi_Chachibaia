
-- picking english language, store and staff
WITH lang AS (
    SELECT language_id
    FROM public.language
    WHERE name = 'English'
    LIMIT 1
),
store_pick AS (
    SELECT store_id
    FROM public.store
    ORDER BY store_id
    LIMIT 1
),
staff_pick AS (
    SELECT s.staff_id
    FROM public.staff s
    JOIN store_pick sp ON s.store_id = sp.store_id
    ORDER BY s.staff_id
    LIMIT 1
)
SELECT 1;
COMMIT;

-- adding my 3 favorite movies
WITH lang AS (
    SELECT language_id
    FROM public.language
    WHERE name = 'English'
    LIMIT 1
),
to_add(title, release_year, rate, duration_weeks) AS (
    VALUES
        ('The Shawshank Redemption', 1994, 4.99, 1),
        ('Interstellar',             2014, 9.99, 2),
        ('The Green Mile',           1999, 19.99, 3)
)
INSERT INTO public.film (
    title, description, release_year, language_id,
    rental_duration, rental_rate, length, replacement_cost,
    rating, last_update
)
SELECT
    t.title, 'added by Gegi', t.release_year, l.language_id,
    t.duration_weeks * 7, t.rate, 120, 19.99,
    'PG-13', current_date
FROM to_add t
CROSS JOIN lang l
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = t.title
)
RETURNING film_id, title;
COMMIT;

-- adding actors and linking them to my movies
WITH films AS (
    SELECT film_id, title
    FROM public.film
    WHERE title IN ('The Shawshank Redemption','Interstellar','The Green Mile')
),
actors(first_name, last_name, film_title) AS (
    VALUES
        ('Tim','Robbins','The Shawshank Redemption'),
        ('Morgan','Freeman','The Shawshank Redemption'),
        ('Matthew','McConaughey','Interstellar'),
        ('Anne','Hathaway','Interstellar'),
        ('Jessica','Chastain','Interstellar'),
        ('Tom','Hanks','The Green Mile'),
        ('Michael','Clarke Duncan','The Green Mile')
),
actor_ins AS (
    INSERT INTO public.actor (first_name, last_name, last_update)
    SELECT a.first_name, a.last_name, current_date
    FROM actors a
    WHERE NOT EXISTS (
        SELECT 1 FROM public.actor x
        WHERE x.first_name = a.first_name AND x.last_name = a.last_name
    )
    RETURNING actor_id, first_name, last_name
),
link AS (
    SELECT ac.actor_id, f.film_id
    FROM public.actor ac
    JOIN actors a ON ac.first_name = a.first_name AND ac.last_name = a.last_name
    JOIN films f ON f.title = a.film_title
)
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT l.actor_id, l.film_id, current_date
FROM link l
WHERE NOT EXISTS (
    SELECT 1 FROM public.film_actor fa
    WHERE fa.actor_id = l.actor_id AND fa.film_id = l.film_id
)
RETURNING film_id, actor_id;
COMMIT;

-- adding these movies to the store inventory
WITH store_pick AS (
    SELECT store_id FROM public.store ORDER BY store_id LIMIT 1
),
films AS (
    SELECT film_id
    FROM public.film
    WHERE title IN ('The Shawshank Redemption','Interstellar','The Green Mile')
)
INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, sp.store_id, current_date
FROM films f CROSS JOIN store_pick sp
WHERE NOT EXISTS (
    SELECT 1 FROM public.inventory i
    WHERE i.film_id = f.film_id AND i.store_id = sp.store_id
)
RETURNING inventory_id, film_id, store_id;
COMMIT;

-- picking a customer with 43+ rentals and payments, updating with my data
WITH chosen AS (
    SELECT c.customer_id
    FROM public.customer c
    WHERE (
        SELECT COUNT(*) FROM public.rental r WHERE r.customer_id = c.customer_id
    ) >= 43
    AND (
        SELECT COUNT(*) FROM public.payment p WHERE p.customer_id = c.customer_id
    ) >= 43
    ORDER BY c.customer_id
    LIMIT 1
),
addr AS (
    SELECT address_id FROM public.address ORDER BY address_id LIMIT 1
)
UPDATE public.customer c
SET first_name = 'Gegi',
    last_name  = 'Chachibaia',
    email      = 'chachibaiagegi@gmail.com',
    address_id = (SELECT address_id FROM addr),
    last_update = current_date
FROM chosen x
WHERE c.customer_id = x.customer_id
RETURNING c.customer_id;
COMMIT;

-- clearing my previous rentals and payments if exist
WITH me AS (
    SELECT customer_id
    FROM public.customer
    WHERE first_name='Gegi' AND last_name='Chachibaia'
    ORDER BY customer_id LIMIT 1
),
del_pay AS (
    DELETE FROM public.payment p USING me
    WHERE p.customer_id = me.customer_id
    RETURNING p.payment_id
),
del_rent AS (
    DELETE FROM public.rental r USING me
    WHERE r.customer_id = me.customer_id
    RETURNING r.rental_id
)
SELECT 
    (SELECT COUNT(*) FROM del_pay)  AS deleted_payments,
    (SELECT COUNT(*) FROM del_rent) AS deleted_rentals;
COMMIT;

-- renting my movies and adding payments (May 8, 2017)
WITH me AS (
    SELECT customer_id
    FROM public.customer
    WHERE first_name='Gegi' AND last_name='Chachibaia'
    ORDER BY customer_id LIMIT 1
),
store_pick AS (
    SELECT store_id FROM public.store ORDER BY store_id LIMIT 1
),
staff_pick AS (
    SELECT s.staff_id
    FROM public.staff s
    JOIN store_pick sp ON s.store_id = sp.store_id
    ORDER BY s.staff_id
    LIMIT 1
),
films AS (
    SELECT film_id, title, rental_rate, rental_duration
    FROM public.film
    WHERE title IN ('The Shawshank Redemption','Interstellar','The Green Mile')
),
inv AS (
    SELECT i.inventory_id, i.film_id
    FROM public.inventory i
    JOIN store_pick sp ON sp.store_id = i.store_id
    WHERE i.film_id IN (SELECT film_id FROM films)
),
dates AS (
    SELECT film_id,
           CASE title
             WHEN 'The Shawshank Redemption' THEN timestamp '2017-05-08 10:00:00'
             WHEN 'Interstellar'             THEN timestamp '2017-05-08 11:00:00'
             WHEN 'The Green Mile'           THEN timestamp '2017-05-08 12:00:00'
           END AS rent_date
    FROM films
),
rent AS (
    INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
    SELECT d.rent_date, i.inventory_id, me.customer_id,
           d.rent_date + (f.rental_duration || ' days')::interval,
           (SELECT staff_id FROM staff_pick),
           current_date
    FROM dates d
    JOIN inv i ON i.film_id = d.film_id
    JOIN films f ON f.film_id = d.film_id
    CROSS JOIN me
    WHERE NOT EXISTS (
        SELECT 1 FROM public.rental r
        WHERE r.customer_id = me.customer_id
        AND r.inventory_id = i.inventory_id
        AND r.rental_date = d.rent_date
    )
    RETURNING rental_id, inventory_id, customer_id, rental_date
),
pay AS (
    INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
    SELECT r.customer_id, (SELECT staff_id FROM staff_pick),
           r.rental_id, f.rental_rate, r.rental_date
    FROM rent r
    JOIN public.inventory i ON i.inventory_id = r.inventory_id
    JOIN films f ON f.film_id = i.film_id
    WHERE NOT EXISTS (
        SELECT 1 FROM public.payment p WHERE p.rental_id = r.rental_id
    )
    RETURNING payment_id
)
SELECT 
    (SELECT COUNT(*) FROM rent) AS rentals_added,
    (SELECT COUNT(*) FROM pay)  AS payments_added;
COMMIT;

