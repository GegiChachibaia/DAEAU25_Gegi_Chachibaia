-- Gegi Chachibaia | Task 2
-- autocommit is ON

-- creating the table (10M rows)
DROP TABLE IF EXISTS table_to_delete;
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

-- just to check it worked
SELECT COUNT(*) FROM table_to_delete;

-- checking table size before doing anything
SELECT *, pg_size_pretty(total_bytes) AS total,
              pg_size_pretty(index_bytes) AS index_size,
              pg_size_pretty(toast_bytes) AS toast,
              pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- deleted 1/3 of rows (slow)
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;

-- checking space again after delete (didn’t change)
SELECT *, pg_size_pretty(total_bytes) AS total,
              pg_size_pretty(index_bytes) AS index_size,
              pg_size_pretty(toast_bytes) AS toast,
              pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- vacuum full to shrink it
VACUUM FULL VERBOSE table_to_delete;

-- checking again after vacuum
SELECT *, pg_size_pretty(total_bytes) AS total,
              pg_size_pretty(index_bytes) AS index_size,
              pg_size_pretty(toast_bytes) AS toast,
              pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- recreating it again for truncate
DROP TABLE IF EXISTS table_to_delete;
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1, (10^7)::int) x;

-- checking size before truncate
SELECT *, pg_size_pretty(total_bytes) AS total,
              pg_size_pretty(index_bytes) AS index_size,
              pg_size_pretty(toast_bytes) AS toast,
              pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- truncate is super fast
TRUNCATE table_to_delete;

-- checking size after truncate
SELECT *, pg_size_pretty(total_bytes) AS total,
              pg_size_pretty(index_bytes) AS index_size,
              pg_size_pretty(toast_bytes) AS toast,
              pg_size_pretty(table_bytes) AS table_size
FROM (
    SELECT *, total_bytes - index_bytes - COALESCE(toast_bytes, 0) AS table_bytes
    FROM (
        SELECT c.oid, nspname AS table_schema, relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

-- report (my notes)
-- table took around 820MB at start
-- delete took about 23 seconds, size stayed the same
-- vacuum full took 16s, dropped to 540MB
-- truncate finished instantly (<1s), table went to almost 0MB
-- truncate is way faster and actually clears space right away
-- delete is slow and useless for full cleanup unless you vacuum
