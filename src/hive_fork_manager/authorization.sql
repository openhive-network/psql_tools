DO $$
BEGIN
    CREATE ROLE hived_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hived_group role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hive_applications_group WITH NOLOGIN;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hive_applications_group role already exists';
END
$$;

-- generic protection for tables in hive schema
-- 1. hived_group allow to edit every table in hive schema
-- 2. hive_applications_group can ready every table in hive schema
-- 3. hive_applications_group can modify hive.contexts, hive.registered_tables, hive.triggers
GRANT ALL ON SCHEMA hive to hived_group, hive_applications_group;
GRANT ALL ON ALL SEQUENCES IN SCHEMA hive TO hived_group, hive_applications_group;
GRANT ALL ON  ALL TABLES IN SCHEMA hive TO hived_group;
GRANT SELECT ON ALL TABLES IN SCHEMA hive TO hive_applications_group;
GRANT ALL ON hive.contexts TO hive_applications_group;
GRANT ALL ON hive.registered_tables TO hive_applications_group;
GRANT ALL ON hive.triggers TO hive_applications_group;

-- protect an application rows aginst other applications
ALTER TABLE hive.contexts ENABLE ROW LEVEL SECURITY;
CREATE POLICY dp_hive_context ON hive.contexts FOR ALL USING ( owner = current_user );
CREATE POLICY sp_hived_hive_context ON hive.contexts FOR SELECT TO hived_group USING( TRUE );
CREATE POLICY sp_applications_hive_context ON hive.contexts FOR SELECT TO hive_applications_group USING( owner = current_user );

ALTER TABLE hive.registered_tables ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_hive_registered_tables ON hive.registered_tables FOR ALL USING ( owner = current_user );

ALTER TABLE hive.triggers ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_hive_triggers ON hive.triggers FOR ALL USING ( owner = current_user );

-- protect api
-- 1. only hived_group and hive_applications_group can invoke functions from hive schema
-- 2. hived_group can use only hived_api
-- 3. hive_applications_group can use every functions from hive schema except hived_api
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA hive FROM PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hive TO hive_applications_group;

GRANT EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync()
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
TO hived_group;

REVOKE EXECUTE ON FUNCTION
      hive.back_from_fork( INT )
    , hive.push_block( hive.blocks, hive.transactions[], hive.transactions_multisig[], hive.operations[] )
    , hive.set_irreversible( INT )
    , hive.end_massive_sync()
    , hive.copy_blocks_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_transactions_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_operations_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.copy_signatures_to_irreversible( _head_block_of_irreversible_blocks INT, _new_irreversible_block INT )
    , hive.remove_obsolete_reversible_data( _new_irreversible_block INT )
    , hive.remove_unecessary_events( _new_irreversible_block INT )
FROM hive_applications_group;
