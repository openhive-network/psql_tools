DROP FUNCTION IF EXISTS hived_test_given;
CREATE FUNCTION hived_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
         , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
         , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
         , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
         , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
    ;
    PERFORM hive.end_massive_sync(5);
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_when;
CREATE FUNCTION hived_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS hived_test_then;
CREATE FUNCTION hived_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS HIVED
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_given;
CREATE FUNCTION alice_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_when;
CREATE FUNCTION alice_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS ALICE
END;
$BODY$
;

DROP FUNCTION IF EXISTS alice_test_then;
CREATE FUNCTION alice_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    BEGIN
        DELETE FROM hive.blocks;
        ASSERT FALSE, 'Alice can delete irreversible blocks';
    EXCEPTION WHEN OTHERS THEN
    END;

BEGIN
    DELETE FROM hive.transactions_multisig;
        ASSERT FALSE, 'Alice can delete irreversible transactions_multisig';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.transactions;
        ASSERT FALSE, 'Alice can delete irreversible transactions';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.operation_types;
        ASSERT FALSE, 'Alice can delete irreversible operation_types';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.operations;
        ASSERT FALSE, 'Alice can delete irreversible operations';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.fork;
        ASSERT FALSE, 'Alice can delete hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hive.fork VALUES( 1, 15, now() );
        ASSERT FALSE, 'Alice can insert to hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.fork SET num = 10;
        ASSERT FALSE, 'Alice can update to hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hive.fork;
        ASSERT FALSE, 'Alice can drop hive.fork';
    EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DELETE FROM hive.events_queue;
        ASSERT FALSE, 'Alice can delete hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        INSERT INTO hive.events_queue VALUES( 1, 'MASSIVE_SYNC', 10 );
        ASSERT FALSE, 'Alice can insert to hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        UPDATE hive.events_queue SET event = 'MASSIVE_SYNC';
        ASSERT FALSE, 'Alice can update to hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;

    BEGIN
        DROP TABLE hive.events_queue;
        ASSERT FALSE, 'Alice can drop hive.events_queue';
        EXCEPTION WHEN OTHERS THEN
    END;
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_given;
CREATE FUNCTION bob_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- PREPARE STATE AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_when;
CREATE FUNCTION bob_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- EXECUTE ACTION UDER TEST AS BOB
END;
$BODY$
;

DROP FUNCTION IF EXISTS bob_test_then;
CREATE FUNCTION bob_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
BEGIN
    -- CHECK EXPECTED STATE AS BOB
END;
$BODY$
;
