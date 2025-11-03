-- The marketing team wants a list of animation movies released between 2017 and 2019
-- with a rental rate higher than 1, sorted alphabetically by title.
-- joins

SELECT 
    f.title
FROM public.film AS f
JOIN public.film_category AS fc ON fc.film_id = f.film_id
JOIN public.category AS c ON c.category_id = fc.category_id
WHERE LOWER(c.name) = 'animation'
  AND f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;

-- Pros: simple and efficient; straightforward for this type of filtering.
-- Cons: can get longer when you need more complex filtering or derived data.

--subquery

SELECT 
    f.title
FROM public.film AS f
WHERE f.film_id IN (
    SELECT fc.film_id
    FROM public.film_category AS fc
    JOIN public.category AS c ON c.category_id = fc.category_id
    WHERE LOWER(c.name) = 'animation'
)
AND f.release_year BETWEEN 2017 AND 2019
AND f.rental_rate > 1
ORDER BY f.title;

-- Pros: keeps the main query focused on film data; easier to read for beginners.
-- Cons: slightly less efficient for large datasets since PostgreSQL must first
--        evaluate the subquery and hold those IDs in memory.


-- cte

WITH animation_films AS (
    SELECT fc.film_id
    FROM public.film_category AS fc
    JOIN public.category AS c ON c.category_id = fc.category_id
    WHERE LOWER(c.name) = 'animation'
)
SELECT 
    f.title
FROM public.film AS f
JOIN animation_films AS af ON f.film_id = af.film_id
WHERE f.release_year BETWEEN 2017 AND 2019
  AND f.rental_rate > 1
ORDER BY f.title;

-- Pros: easy to understand and maintain; clean separation between logic steps.
-- Cons: may add minimal overhead since the CTE is materialized before filtering.




-- The finance department needs a report showing how each store performed
-- after March 2017 to evaluate profitability and plan resource allocation.
-- The query calculates total revenue per store and combines address fields
-- into a single column for clarity.

SELECT 
    adr.address || ' ' || COALESCE(adr.address2, '') AS store_address,  -- merge address fields
    SUM(pay.amount) AS revenue                                            -- total payments per store
FROM public.payment AS pay
JOIN public.rental AS r ON r.rental_id = pay.rental_id
JOIN public.inventory AS i ON i.inventory_id = r.inventory_id
JOIN public.store AS s ON s.store_id = i.store_id
JOIN public.address AS adr ON adr.address_id = s.address_id
WHERE pay.payment_date >= '2017-04-01'                                    -- include only payments after March 2017
GROUP BY adr.address || ' ' || COALESCE(adr.address2, '')                 -- group results by store address
ORDER BY revenue DESC;                                                    -- optional: sort by highest revenue

-- Pros: straightforward and efficient for aggregating data from related tables.
-- Cons: joins can become complex in larger queries; the concatenation in GROUP BY
--        may slightly reduce readability or performance on big datasets.

SELECT 
    addr.shop_addr AS store_address, 
    SUM(pay.amount) AS revenue
FROM public.payment AS pay
JOIN (
    -- Prepare a list of rentals with their corresponding store addresses
    SELECT 
        adr.address || ' ' || COALESCE(adr.address2, '') AS shop_addr,
        r.rental_id
    FROM public.address AS adr
    JOIN public.store AS s ON s.address_id = adr.address_id
    JOIN public.inventory AS i ON i.store_id = s.store_id
    JOIN public.rental AS r ON r.inventory_id = i.inventory_id
) AS addr ON addr.rental_id = pay.rental_id
WHERE pay.payment_date >= '2017-04-01'      -- include only payments after March 2017
GROUP BY addr.shop_addr
ORDER BY revenue DESC;                      -- optional: sort by highest revenue

-- Pros: separates address logic from main query, making the main part simpler to read.
-- Cons: subqueries can be less efficient on large datasets, since PostgreSQL
--        might need to materialize the subquery before joining.

WITH store_addresses AS (
    -- Create a list of rentals with their full store address
    SELECT 
        adr.address || ' ' || COALESCE(adr.address2, '') AS shop_addr,
        r.rental_id
    FROM public.address AS adr
    JOIN public.store AS s ON s.address_id = adr.address_id
    JOIN public.inventory AS i ON i.store_id = s.store_id
    JOIN public.rental AS r ON r.inventory_id = i.inventory_id
)

SELECT 
    sa.shop_addr AS store_address,
    SUM(pay.amount) AS revenue
FROM public.payment AS pay
JOIN store_addresses AS sa ON sa.rental_id = pay.rental_id
WHERE pay.payment_date >= '2017-04-01'      -- include only payments after March 2017
GROUP BY sa.shop_addr
ORDER BY revenue DESC;                      -- optional: show most profitable stores first

-- Pros: easier to understand and maintain since address logic is separated.
-- Cons: slightly more overhead on small datasets, as PostgreSQL
--        builds the CTE before processing the main query.


-- The marketing department wants to find the top 5 actors
-- who have appeared in the most movies released after 2015.
-- This information will be used to promote popular actors
-- and attract customer attention to their films.

SELECT 
    a.first_name,
    a.last_name,
    COUNT(DISTINCT fa.film_id) AS number_of_movies     -- count how many different films each actor appeared in
FROM public.actor AS a
JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
JOIN public.film AS f ON f.film_id = fa.film_id
WHERE f.release_year >= 2015                           -- include only films released since 2015
GROUP BY a.actor_id
ORDER BY number_of_movies DESC                         -- sort actors by total film count
LIMIT 5;                                               -- show only the top 5 actors

-- Pros: efficient and straightforward way to find top results using joins and aggregation.
-- Cons: grouping only by actor_id means first/last names come from that ID; 
--        for ties, exact ranking between actors with same count isn’t handled explicitly.

--subquery logic

SELECT 
    a.first_name,
    a.last_name,
    COUNT(DISTINCT fa.film_id) AS number_of_movies      -- count unique movies per actor
FROM public.actor AS a
JOIN public.film_actor AS fa 
    ON a.actor_id = fa.actor_id
WHERE fa.film_id IN (
    -- Get IDs of all films released after 2015
    SELECT f.film_id
    FROM public.film AS f
    WHERE f.release_year >= 2015
)
GROUP BY a.actor_id
ORDER BY number_of_movies DESC                         -- sort by number of movies
LIMIT 5;                                               -- keep only top 5 actors

-- Pros: keeps the filtering logic for movies separate, making it easy to adjust later.
-- Cons: slightly less efficient on large datasets since the subquery list
--        must be built and compared against; JOINs are usually faster for this.

--cte

WITH recent_films AS (
    -- Keep only film IDs for movies released since 2015
    SELECT f.film_id
    FROM public.film AS f
    WHERE f.release_year >= 2015
)

SELECT 
    a.first_name,
    a.last_name,
    COUNT(DISTINCT fa.film_id) AS number_of_movies     -- count unique films per actor
FROM public.actor AS a
JOIN public.film_actor AS fa ON a.actor_id = fa.actor_id
JOIN recent_films AS rf ON rf.film_id = fa.film_id
GROUP BY a.actor_id
ORDER BY number_of_movies DESC
LIMIT 5;

-- Pros: keeps the query organized and easier to maintain;
--        the film filter is clearly separated from the aggregation.
-- Cons: CTE adds a small overhead since PostgreSQL builds it first;
--        for short queries, a direct join might be slightly faster.

-- The marketing team wants to analyze production trends of Drama, Travel, and Documentary films
-- by year to support genre-based marketing decisions.
--joins

SELECT 
    f.release_year,
    COUNT(f.film_id) FILTER (WHERE LOWER(c.name) = 'drama')       AS number_of_drama_movies,
    COUNT(f.film_id) FILTER (WHERE LOWER(c.name) = 'travel')      AS number_of_travel_movies,
    COUNT(f.film_id) FILTER (WHERE LOWER(c.name) = 'documentary') AS number_of_documentary_movies
FROM public.film_category AS fc
JOIN public.film AS f ON f.film_id = fc.film_id
JOIN public.category AS c ON c.category_id = fc.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;

-- Pros: simple and efficient since all related tables are joined directly.
-- Cons: not flexible if more genres are added later; must edit the FILTER list manually.

--cte

WITH film_genres AS (
    SELECT 
        f.release_year,
        LOWER(c.name) AS genre
    FROM public.film AS f
    JOIN public.film_category AS fc ON fc.film_id = f.film_id
    JOIN public.category AS c ON c.category_id = fc.category_id
)
SELECT 
    fg.release_year,
    COUNT(*) FILTER (WHERE genre = 'drama')       AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE genre = 'travel')      AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE genre = 'documentary') AS number_of_documentary_movies
FROM film_genres AS fg
GROUP BY fg.release_year
ORDER BY fg.release_year DESC;

-- Pros: improves readability and maintainability by keeping joins in a separate step.
-- Cons: slightly more overhead since PostgreSQL builds the CTE before aggregation.

--subquery

SELECT 
    sub.release_year,
    COUNT(*) FILTER (WHERE genre = 'drama')       AS number_of_drama_movies,
    COUNT(*) FILTER (WHERE genre = 'travel')      AS number_of_travel_movies,
    COUNT(*) FILTER (WHERE genre = 'documentary') AS number_of_documentary_movies
FROM (
    SELECT 
        f.release_year,
        LOWER(c.name) AS genre
    FROM public.film AS f
    JOIN public.film_category AS fc ON fc.film_id = f.film_id
    JOIN public.category AS c ON c.category_id = fc.category_id
) AS sub
GROUP BY sub.release_year
ORDER BY sub.release_year DESC;

-- Pros: keeps the filtering logic self-contained without defining a CTE.
-- Cons: slightly less readable for larger queries and can be less efficient
--        if the subquery result set is large.



-- The HR department wants to find the three employees who generated
-- the highest revenue in 2017 to reward them with bonuses.
-- joins

SELECT 
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_name,
    s.store_id,
    SUM(p.amount) AS total_revenue
FROM public.staff AS s
JOIN public.payment AS p ON s.staff_id = p.staff_id
WHERE EXTRACT(YEAR FROM p.payment_date) = 2017     -- filter by year
GROUP BY s.staff_id, s.first_name, s.last_name, s.store_id
ORDER BY total_revenue DESC
LIMIT 3;

-- Pros: direct and efficient since both tables are connected by foreign key.
-- Cons: less flexibility if additional filtering logic or derived data is needed later.

--cte

WITH staff_revenue AS (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
)
SELECT 
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_name,
    s.store_id,
    sr.total_revenue
FROM public.staff AS s
JOIN staff_revenue AS sr ON s.staff_id = sr.staff_id
ORDER BY sr.total_revenue DESC
LIMIT 3;

-- Pros: easy to read and modify; revenue logic is clearly separated.
-- Cons: slightly less efficient for small queries since PostgreSQL must build the CTE first.

-- subquery

SELECT 
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_name,
    s.store_id,
    sub.total_revenue
FROM public.staff AS s
JOIN (
    SELECT 
        p.staff_id,
        SUM(p.amount) AS total_revenue
    FROM public.payment AS p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
) AS sub ON sub.staff_id = s.staff_id
ORDER BY sub.total_revenue DESC
LIMIT 3;

-- Pros: keeps revenue calculation self-contained, making main query simpler.
-- Cons: can be less readable with nested logic and harder to extend if new columns are needed.

-- The management team wants to identify the 5 most rented movies
-- and determine the expected audience age group for each film
-- based on the Motion Picture Association rating system.
--join

SELECT 
    f.film_id,
    f.title,
    f.rating,
    CASE 
        WHEN f.rating = 'G'     THEN 'General audiences. Suitable for all ages.'
        WHEN f.rating = 'PG'    THEN 'Parental Guidance Suggested. 8+, parental guidance suggested, especially for younger children.'
        WHEN f.rating = 'PG-13' THEN 'Parents Strongly Cautioned. 13+.'
        WHEN f.rating = 'R'     THEN 'Restricted. 17+, under 17 requires adult supervision.'
        WHEN f.rating = 'NC-17' THEN 'Adults Only. 18+, no one 17 or under admitted.'
    END AS rating_description,
    COUNT(f.film_id) AS rental_count
FROM public.rental AS r
JOIN public.inventory AS i ON i.inventory_id = r.inventory_id
JOIN public.film AS f ON f.film_id = i.film_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY rental_count DESC
LIMIT 5;

-- Pros: direct and efficient; joins connect all tables clearly.
-- Cons: not very modular—if you reuse logic, you’d repeat it in each query.

-- cte

WITH film_rentals AS (
    SELECT 
        f.film_id,
        f.title,
        f.rating,
        COUNT(f.film_id) AS rental_count
    FROM public.film AS f
    JOIN public.inventory AS i ON i.film_id = f.film_id
    JOIN public.rental AS r ON r.inventory_id = i.inventory_id
    GROUP BY f.film_id, f.title, f.rating
)
SELECT 
    fr.film_id,
    fr.title,
    fr.rating,
    CASE 
        WHEN fr.rating = 'G'     THEN 'General audiences. Suitable for all ages.'
        WHEN fr.rating = 'PG'    THEN 'Parental Guidance Suggested. 8+, parental guidance suggested, especially for younger children.'
        WHEN fr.rating = 'PG-13' THEN 'Parents Strongly Cautioned. 13+.'
        WHEN fr.rating = 'R'     THEN 'Restricted. 17+, under 17 requires adult supervision.'
        WHEN fr.rating = 'NC-17' THEN 'Adults Only. 18+, no one 17 or under admitted.'
    END AS rating_description,
    fr.rental_count
FROM film_rentals AS fr
ORDER BY fr.rental_count DESC
LIMIT 5;

-- Pros: separates rental counting from presentation logic, making query easy to maintain.
-- Cons: adds slight overhead since PostgreSQL materializes the CTE before sorting.

--subquery

SELECT 
    sub.film_id,
    sub.title,
    sub.rating,
    CASE 
        WHEN sub.rating = 'G'     THEN 'General audiences. Suitable for all ages.'
        WHEN sub.rating = 'PG'    THEN 'Parental Guidance Suggested. 8+, parental guidance suggested, especially for younger children.'
        WHEN sub.rating = 'PG-13' THEN 'Parents Strongly Cautioned. 13+.'
        WHEN sub.rating = 'R'     THEN 'Restricted. 17+, under 17 requires adult supervision.'
        WHEN sub.rating = 'NC-17' THEN 'Adults Only. 18+, no one 17 or under admitted.'
    END AS rating_description,
    sub.rental_count
FROM (
    SELECT 
        f.film_id,
        f.title,
        f.rating,
        COUNT(f.film_id) AS rental_count
    FROM public.film AS f
    JOIN public.inventory AS i ON i.film_id = f.film_id
    JOIN public.rental AS r ON r.inventory_id = i.inventory_id
    GROUP BY f.film_id, f.title, f.rating
) AS sub
ORDER BY sub.rental_count DESC
LIMIT 5;

-- Pros: keeps counting logic isolated, making the outer query simpler.
-- Cons: less flexible if additional conditions are needed in the outer query.

/* 
PROBLEM:
The management team wants to identify actors who have had the longest break
since their most recent movie release. Show actor_id, first_name, last_name,
and the gap (in years) between the current year and the actor’s latest release year.
Return all actors who share this maximum gap.
*/

-- joins
SELECT 
    actor_id,
    first_name,
    last_name,
    gap
FROM (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        EXTRACT(YEAR FROM current_date) - MAX(f.release_year) AS gap,
        RANK() OVER (ORDER BY EXTRACT(YEAR FROM current_date) - MAX(f.release_year) DESC) AS rank_position
    FROM public.actor AS a
    JOIN public.film_actor AS fa ON fa.actor_id = a.actor_id
    JOIN public.film AS f ON f.film_id = fa.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
) ranked
WHERE rank_position = 1          -- keep only actors with the maximum gap
ORDER BY actor_id;

-- Pros: works in all PostgreSQL versions; easy to extend or filter further.
-- Cons: window functions can be slightly heavier on very large datasets.

-- CTE

WITH actor_gaps AS (
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        EXTRACT(YEAR FROM current_date) - MAX(f.release_year) AS gap
    FROM public.actor AS a
    JOIN public.film_actor AS fa ON fa.actor_id = a.actor_id
    JOIN public.film AS f ON f.film_id = fa.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT 
    ag.actor_id,
    ag.first_name,
    ag.last_name,
    ag.gap
FROM actor_gaps AS ag
WHERE ag.gap = (SELECT MAX(gap) FROM actor_gaps)
ORDER BY ag.actor_id;

-- Pros: clear and readable; separates aggregation from filtering.
-- Cons: adds a tiny overhead due to materializing the CTE.


-- subquery

SELECT 
    s.actor_id,
    s.first_name,
    s.last_name,
    s.gap
FROM (
    -- calculate each actor's gap
    SELECT 
        a.actor_id,
        a.first_name,
        a.last_name,
        EXTRACT(YEAR FROM current_date) - MAX(f.release_year) AS gap
    FROM public.actor AS a
    JOIN public.film_actor AS fa ON fa.actor_id = a.actor_id
    JOIN public.film AS f ON f.film_id = fa.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
) AS s
WHERE s.gap = (
    -- get the maximum gap among all actors
    SELECT MAX(sub.gap)
    FROM (
        SELECT 
            EXTRACT(YEAR FROM current_date) - MAX(f2.release_year) AS gap
        FROM public.actor AS a2
        JOIN public.film_actor AS fa2 ON fa2.actor_id = a2.actor_id
        JOIN public.film AS f2 ON f2.film_id = fa2.film_id
        GROUP BY a2.actor_id
    ) AS sub
)
ORDER BY s.actor_id;

-- Pros: fully self-contained, no window functions or FETCH needed.
-- Cons: nested subqueries can be slower for very large datasets.

