CREATE OR REPLACE FUNCTION hive.start_provider_accounts( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := 'accounts_' || _context;
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'CREATE TABLE hive.%I(
                      id SERIAL
                    , name TEXT
                    , CONSTRAINT pk_%s PRIMARY KEY( id )
                    )', __table_name, __table_name
    );

    RETURN ARRAY[ 'hive.' || __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.update_state_provider_accounts( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := 'accounts_' || _context;
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'INSERT INTO hive.accounts_%s( name )
        SELECT ''test_name'' as name
        FROM hive.%s_operations_view ov
        JOIN hive.operation_types ot ON ov.op_type_id = ot.id
        WHERE
            ARRAY[ lower( ot.name ) ] @> ARRAY[ ''pow'', ''pow2'', ''accountcreate'', ''accountcreatewithdelegation'', ''createclaimedaccount'' ]
            AND ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, _context, _first_block, _last_block
    );
END;
$BODY$
;
