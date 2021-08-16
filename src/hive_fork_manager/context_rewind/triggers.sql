CREATE OR REPLACE FUNCTION hive.create_triggers( _table_schema TEXT,  _table_name TEXT, _context_id hive.contexts.id%TYPE )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __shadow_table_name TEXT := 'shadow_' || lower(_table_schema) || '_' || lower(_table_name);
    __hive_insert_trigger_name TEXT := 'hive_insert_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_delete_trigger_name TEXT := 'hive_delete_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_update_trigger_name TEXT := 'hive_update_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_truncate_trigger_name TEXT := 'hive_truncate_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_insert TEXT := 'hive_on_table_trigger_insert_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_delete TEXT := 'hive_on_table_trigger_delete_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_update TEXT := 'hive_on_table_trigger_update_' || lower(_table_schema) || '_' || _table_name;
    __hive_triggerfunction_name_truncate TEXT := 'hive_on_table_trigger_truncate_' || lower(_table_schema) || '_' || _table_name;
    __new_sequence_name TEXT := 'seq_' || lower(_table_schema) || '_' || lower(_table_name);
    __registered_table_id INTEGER := NULL;
    __columns_names TEXT[];
BEGIN
    -- register insert trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT ON %s.%s REFERENCING NEW TABLE AS NEW_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_insert_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_insert
            , _context_id
            , __shadow_table_name
    );

    -- register delete trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER DELETE ON %s.%s REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_delete_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_delete
            , _context_id
            , __shadow_table_name
    );

    -- register update trigger
    EXECUTE format(
            'CREATE TRIGGER %I AFTER UPDATE ON %s.%s REFERENCING OLD TABLE AS OLD_TABLE FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_update_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_update
            , _context_id
            , __shadow_table_name
    );

    -- register truncate trigger
    EXECUTE format(
            'CREATE TRIGGER %I BEFORE TRUNCATE ON %s.%s FOR EACH STATEMENT EXECUTE PROCEDURE %s( %L, %L )'
            , __hive_truncate_trigger_name
            , _table_schema
            , _table_name
            , __hive_triggerfunction_name_truncate
            , _context_id
            , __shadow_table_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_triggers( _table_schema TEXT,  _table_name TEXT )
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __hive_insert_trigger_name TEXT := 'hive_insert_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_delete_trigger_name TEXT := 'hive_delete_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_update_trigger_name TEXT := 'hive_update_trigger_' || lower(_table_schema) || '_' || _table_name;
    __hive_truncate_trigger_name TEXT := 'hive_truncate_trigger_' || lower(_table_schema) || '_' || _table_name;
BEGIN
        -- register insert trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_insert_trigger_name
            , _table_schema
            , _table_name
        );

    -- register delete trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_delete_trigger_name
            , _table_schema
            , _table_name
        );

    -- register update trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_update_trigger_name
            , _table_schema
            , _table_name
        );

    -- register truncate trigger
    EXECUTE format(
            'DROP TRIGGER %I ON %s.%s'
            , __hive_truncate_trigger_name
            , _table_schema
            , _table_name
        );
END;
$BODY$
;