DROP FUNCTION IF EXISTS hive_on_table_trigger;
CREATE FUNCTION hive_on_table_trigger()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$BODY$
DECLARE
    __block_num INTEGER := NULL;
    __values TEXT;
BEGIN
    ASSERT TG_NARGS = 2; --context id, shadow_table name

    SELECT hc.current_block_num FROM hive_contexts hc WHERE hc.id = CAST( TG_ARGV[ 0 ] as INTEGER ) INTO __block_num;

    ASSERT __block_num IS NOT NULL;

    IF ( __block_num < 0 ) THEN
        RAISE EXCEPTION 'Did not execute hive_context_next_block before table edition';
    END IF;

    IF ( TG_OP = 'INSERT' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 0'
            , TG_ARGV[ 1 ] -- shadow table name
            , __block_num )
            USING NEW;
        RETURN NEW;
    END IF;

    IF ( TG_OP = 'DELETE' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 1'
            , TG_ARGV[ 1 ] -- shadow table name
            , __block_num )
            USING OLD;
        RETURN NEW;
    END IF;

    IF ( TG_OP = 'UPDATE' ) THEN
        EXECUTE format( 'INSERT INTO %I SELECT ($1).*, %s, 2'
            , TG_ARGV[ 1 ] -- shadow table name
            , __block_num )
            USING OLD;
        RETURN NEW;
    END IF;

    ASSERT FALSE, 'Unsuported trigger operation';
END;
$BODY$