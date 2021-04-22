﻿DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TABLE table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.base );
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_name='table1' AND column_name='hive_rowid' );

    ASSERT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'shadow_public_table1' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_public_table1' AND column_name='hive_block_num' AND data_type='integer' );
    ASSERT EXISTS ( SELECT FROM information_schema.columns WHERE table_schema='hive' AND table_name='shadow_public_table1' AND column_name='hive_operation_type' AND data_type='smallint' );
    ASSERT EXISTS ( SELECT FROM hive.registered_tables WHERE origin_table_schema='public' AND origin_table_name='table1' AND shadow_table_name='shadow_public_table1' );

    -- triggers
    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_insert_trigger_public_table1' AND function_name='hive_on_table_trigger_insert_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_insert_trigger_public_table1');
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_insert_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_delete_trigger_public_table1' AND function_name='hive_on_table_trigger_delete_public_table1'  );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_delete_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_delete_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_update_trigger_public_table1' AND function_name='hive_on_table_trigger_update_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_update_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_update_public_table1');

    ASSERT EXISTS ( SELECT FROM hive.triggers WHERE trigger_name='hive_truncate_trigger_public_table1' AND function_name='hive_on_table_trigger_truncate_public_table1' );
    ASSERT EXISTS ( SELECT FROM pg_trigger WHERE tgname='hive_truncate_trigger_public_table1' );
    ASSERT EXISTS ( SELECT * FROM pg_proc WHERE proname = 'hive_on_table_trigger_truncate_public_table1');
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();