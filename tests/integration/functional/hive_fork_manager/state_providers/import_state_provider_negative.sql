DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
    PERFORM hive.import_state_provider( 'ACCOUNTS', 'context' );
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
        BEGIN
        PERFORM hive.import_state_provider( 'ACCOUNTS', 'not-existed-context' );
            ASSERT FALSE, 'Cannot raise expected exception when context does not exists';
        EXCEPTION WHEN OTHERS THEN
        END;

        BEGIN
        PERFORM hive.import_state_provider( 'ACCOUNTS', 'context' );
            ASSERT FALSE, 'Cannot raise expected exception when provider is registered twice';
        EXCEPTION WHEN OTHERS THEN
        END;
END;
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
    -- NOTHING TO CHECK HERE
END;
$BODY$
;




