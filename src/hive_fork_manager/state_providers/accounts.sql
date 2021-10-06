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