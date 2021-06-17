CREATE OR REPLACE FUNCTION hive.chceck_constrains( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    STABLE
AS
$BODY$
DECLARE
    __exists_non_defferable BOOL := FALSE;
    __constraint_name TEXT;
BEGIN
    EXECUTE format( 'SELECT EXISTS(
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_catalog = current_database()
              AND constraint_type != ''CHECK''
              AND constraint_type != ''PRIMARY KEY''
              AND constraint_type != ''UNIQUE''
              AND constraint_type != ''EXCLUDE''
              AND is_deferrable = ''NO''
              AND table_schema=''%I'' AND table_name=''%I'' )'
    , _table_schema, _table_name )
    INTO __exists_non_defferable;

    IF __exists_non_defferable = TRUE THEN
        RAISE EXCEPTION 'A registered table cannot have non-deferrable referenced constraints. Please check constraints on table %.%'
            , _table_schema, _table_name;
    END IF;
END;
$BODY$
;


-- block registerd tables trigger
CREATE OR REPLACE FUNCTION hive.on_edit_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__result BOOL := NULL;
__r RECORD;
__shadow_table_name TEXT := NULL;
__origin_table_schema TEXT;
__origin_table_name TEXT;
__new_columns TEXT[];
BEGIN
    SELECT hrt.shadow_table_name, hrt.origin_table_schema, hrt.origin_table_name  FROM
        ( SELECT * FROM pg_event_trigger_ddl_commands() ) as tr
        JOIN hive.registered_tables hrt ON ( hrt.origin_table_schema || '.' || hrt.origin_table_name ) = tr.object_identity
        JOIN hive.contexts hc ON hrt.context_id = hc.id
        WHERE hc.back_from_fork = FALSE
    INTO __shadow_table_name, __origin_table_schema, __origin_table_name;

    IF __shadow_table_name IS NULL THEN
        RETURN;
    END IF;

    EXECUTE format( 'SELECT EXISTS( SELECT * FROM hive.%I LIMIT 1 )', __shadow_table_name ) INTO __result;

    IF __result = TRUE THEN
        RAISE EXCEPTION 'Cannot edit structure of registered tables when some rows are not rewinded';
    END IF;

    SELECT EXISTS (
        SELECT *
        FROM information_schema.columns iss
        WHERE iss.table_schema = __origin_table_schema
            AND iss.table_name = __origin_table_name
            AND iss.column_name = 'hive_rowid'
    ) INTO __result;

    IF __result = FALSE THEN
        RAISE EXCEPTION 'Cannot remove hive_rowid column';
    END IF;

    -- drop shadow table with old format
    EXECUTE format( 'DROP TABLE hive.%I', __shadow_table_name );
    PERFORM hive.create_shadow_table( __origin_table_schema, __origin_table_name );

    --update information about columns
    SELECT array_agg( iss.column_name::TEXT ) INTO __new_columns
    FROM information_schema.columns iss
    WHERE iss.table_schema = __origin_table_schema AND iss.table_name = __origin_table_name;

    UPDATE hive.registered_tables hrt
    SET origin_table_columns = __new_columns
    WHERE hrt.origin_table_name = lower( __origin_table_name ) AND hrt.origin_table_schema = lower( __origin_table_schema );

    PERFORM hive.chceck_constrains( lower( __origin_table_schema ),  __origin_table_name );
    PERFORM hive.create_revert_functions( lower( __origin_table_schema ),  __origin_table_name, __shadow_table_name, __new_columns );
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_drop_registered_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
__r RECORD;
__table TEXT := NULL;
__schema TEXT := NULL;
BEGIN
    SELECT tr.object_name, tr.schema_name  FROM
    ( SELECT * FROM pg_event_trigger_dropped_objects() ) as tr
        JOIN hive.registered_tables hrt ON hrt.origin_table_name  = tr.object_name AND hrt.origin_table_schema = tr.schema_name
    WHERE tr.object_type ='table'
    INTO __table, __schema;

    IF __table IS NOT NULL THEN
        PERFORM hive.clean_after_uregister_table( __schema, __table );
        RAISE WARNING 'Registered table were dropped: %.%', __schema, __table;
    END IF;
END;
$$
;

CREATE OR REPLACE FUNCTION hive.on_create_tables()
    RETURNS event_trigger
    LANGUAGE plpgsql
AS
$$
DECLARE
    __newest_context TEXT :=  NULL;
BEGIN
    SELECT hc.name FROM hive.contexts hc ORDER BY hc.id DESC LIMIT 1 INTO __newest_context;

    PERFORM hive.register_table( tables.schema_name, tables.relname,  __newest_context ), hive.chceck_constrains(tables.schema_name, tables.relname)
    FROM (
        SELECT DISTINCT( pgc.relname ), tr.schema_name
        FROM pg_event_trigger_ddl_commands() as tr
        JOIN pg_catalog.pg_inherits pgi ON tr.objid = pgi.inhrelid
        JOIN pg_class pgc ON pgc.oid = tr.objid
        WHERE tr.object_type = 'table' AND pgi.inhparent = 'hive.base'::regclass
    ) as tables;

END;
$$
;

DROP EVENT TRIGGER IF EXISTS hive_block_edit_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_edit_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'ALTER TABLE' )
EXECUTE PROCEDURE hive.on_edit_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_block_drop_registered_tables_trigger;
CREATE EVENT TRIGGER hive_block_drop_registered_tables_trigger ON sql_drop
WHEN TAG IN ( 'DROP TABLE' )
EXECUTE PROCEDURE hive.on_drop_registered_tables();

DROP EVENT TRIGGER IF EXISTS hive_create_registered_tables_trigger;
CREATE EVENT TRIGGER hive_create_registered_tables_trigger ON ddl_command_end
WHEN TAG IN ( 'CREATE TABLE' )
EXECUTE PROCEDURE hive.on_create_tables();