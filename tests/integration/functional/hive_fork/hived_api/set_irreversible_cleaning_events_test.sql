DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    ;

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.base );

    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 1
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 2
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 3
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 4
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
DECLARE
    __result INT;
BEGIN
    PERFORM hive.set_irreversible( 3 );
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
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 3, 'Wrong number of events';
    ASSERT EXISTS ( SELECT * FROM hive.events_queue WHERE event = 'NEW_BLOCK' AND block_num=3 ), 'No NEW_BLOCK event 3';
    ASSERT EXISTS ( SELECT * FROM hive.events_queue WHERE event = 'NEW_BLOCK' AND block_num=4 ), 'No NEW_BLOCK event 4';
    ASSERT EXISTS ( SELECT * FROM hive.events_queue WHERE event = 'NEW_IRREVERSIBLE' AND block_num=3 ), 'No NEW_IRREVERSIBLE event';
END;
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();