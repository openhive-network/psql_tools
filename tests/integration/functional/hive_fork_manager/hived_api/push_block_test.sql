DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.operation_types
    VALUES (0, 'OP 0', FALSE )
        , ( 1, 'OP 1', FALSE )
        , ( 2, 'OP 2', FALSE )
        , ( 3, 'OP 3', TRUE )
    ;
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
    __block hive.blocks%ROWTYPE;
    __transaction1 hive.transactions%ROWTYPE;
    __transaction2 hive.transactions%ROWTYPE;
    __operation1_1 hive.operations%ROWTYPE;
    __operation2_1 hive.operations%ROWTYPE;
    __signatures1 hive.transactions_multisig%ROWTYPE;
    __signatures2 hive.transactions_multisig%ROWTYPE;
BEGIN
    __block = ( 101, '\xBADD', '\xCAFE', '2016-06-22 19:10:25-07'::timestamp );
    __transaction1 = ( 101, 0::SMALLINT, '\xDEED', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xBEEF' );
    __transaction2 = ( 101, 1::SMALLINT, '\xBEEF', 101, 100, '2016-06-22 19:10:25-07'::timestamp, '\xDEED' );
    __operation1_1 = ( 1, 101, 0, 0, 1, '2016-06-22 19:10:21-07'::timestamp, 'ZERO OPERATION' );
    __operation2_1 = ( 2, 101, 1, 0, 2, '2016-06-22 19:10:21-07'::timestamp, 'ONE OPERATION' );
    __signatures1 = ( '\xDEED', '\xFEED' );
    __signatures2 = ( '\xBEEF', '\xBABE' );
    PERFORM hive.push_block(
          __block
        , ARRAY[ __transaction1, __transaction2 ]
        , ARRAY[ __signatures1, __signatures2 ]
        , ARRAY[ __operation1_1, __operation2_1 ]
    );
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
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE id = 1 AND event = 'NEW_BLOCK' AND block_num = 101 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 2, 'Unexpected number of events';

    ASSERT ( SELECT COUNT(*) FROM hive.blocks_reversible ) = 1, 'Unexpected number of blocks';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible ) = 2, 'Unexpected number of transactions';
    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible ) = 2, 'Unexpected number of signatures';
    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible ) = 2, 'Unexpected number of operations';

    ASSERT  ( SELECT COUNT(*) FROM hive.blocks_reversible
                    WHERE
                        num=101
                    AND hash='\xBADD'
                    AND prev='\xCAFE'
                    AND created_at='2016-06-22 19:10:25-07'::timestamp
                    AND fork_id = 1
    ) = 1, 'Wrong block data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible
                    WHERE
                        block_num=101
                    AND trx_in_block=0
                    AND trx_hash='\xDEED'
                    AND ref_block_num=101
                    AND ref_block_prefix=100
                    AND expiration='2016-06-22 19:10:25-07'::timestamp
                    AND signature='\xBEEF'
                    AND fork_id = 1
    ) = 1, 'Wrong 1 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_reversible
           WHERE
               block_num=101
           AND trx_in_block=1
           AND trx_hash='\xBEEF'
           AND ref_block_num=101
           AND ref_block_prefix=100
           AND expiration='2016-06-22 19:10:25-07'::timestamp
           AND signature='\xDEED'
           AND fork_id = 1
    ) = 1, 'Wrong 2 transaction data'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible
            WHERE trx_hash = '\xDEED' AND signature = '\xFEED' AND fork_id = 1
    ) = 1, 'Wrong data of signature 1'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.transactions_multisig_reversible
         WHERE trx_hash = '\xBEEF' AND signature = '\xBABE' AND fork_id = 1
             ) = 1, 'Wrong data of signature 2'
    ;

    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible
        WHERE
                  id = 1
              AND block_num = 101
              AND trx_in_block = 0
              AND op_pos = 0
              AND op_type_id = 1
              AND timestamp = '2016-06-22 19:10:21-07'::timestamp
              AND body = 'ZERO OPERATION'
              AND fork_id = 1
    ) = 1, 'Wrong data of operation 1';

    ASSERT ( SELECT COUNT(*) FROM hive.operations_reversible
         WHERE
               id = 2
           AND block_num = 101
           AND trx_in_block = 1
           AND op_pos = 0
           AND op_type_id = 2
           AND timestamp = '2016-06-22 19:10:21-07'::timestamp
           AND body = 'ONE OPERATION'
           AND fork_id = 1
     ) = 1, 'Wrong data of operation 2';

END
$BODY$
;




