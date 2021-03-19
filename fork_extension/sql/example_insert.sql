﻿--Example of fork_extention usage
--The plugin has not been finished yet, and at the moment it can be only considered as a demo version to show its potential

--0. Load the extension plugin
LOAD '$libdir/plugins/libfork_extension.so';

--1. Lets create some not trivial tables
--1.a custom type to proof that they can be supported
DROP TYPE IF EXISTS custom_type CASCADE;
CREATE TYPE custom_type AS (
	id INTEGER,
	val FLOAT,
	name TEXT
);
--1.b a table with different kind of column types. It will be filled by the client
DROP TABLE IF EXISTS src_table;
CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

--2. Create trigger ( function on_table_change()  was added by the plugin during loading )
CREATE TRIGGER on_src_table_change AFTER INSERT ON src_table
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();

--3. Make operations on src_table
--3.a Insert 10000 rows to src table, each of them will be copied to the tuples table
INSERT INTO src_table ( smth, name, values, data, name2, num ) 
SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
FROM generate_series(1, 10000) AS gen(id)
JOIN ( VALUES( 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;
--3.b remove all previously added rows, the removed rows will be saved in 'tuples' table

--4 deserialize saved tuples to rows in src_table
SELECT back_from_fork(); -- 51ms,41ms,41ms

--4.a check that tuples are deserialized
SELECT * FROM src_table  LIMIT 100;

-- Cleanup things added by plugin
DROP FUNCTION IF EXISTS on_table_change CASCADE;
DROP FUNCTION IF EXISTS back_from_fork CASCADE;
DROP TABLE IF EXISTS tuples;
