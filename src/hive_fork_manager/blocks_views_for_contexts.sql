CREATE OR REPLACE FUNCTION hive.create_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_context_data_view AS
        SELECT
        hc.current_block_num,
        hc.irreversible_block,
        hc.is_attached,
        hc.fork_id,
        CASE hc.is_attached
          WHEN true THEN LEAST(hc.irreversible_block, hc.current_block_num)
          ELSE 2147483647
        END AS min_block,
        CASE hc.is_attached
          WHEN true THEN hc.current_block_num > hc.irreversible_block and exists (SELECT NULL::text FROM hive.registered_tables hrt
                                              WHERE hrt.context_id = hc.id)
          ELSE false
        END AS reversible_range
        FROM hive.contexts hc
        WHERE hc.name::text = ''%s''::text
        limit 1
        ;', _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_context_data_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format( 'DROP VIEW hive.%s_context_data_view;', _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_blocks_view
        AS
        SELECT t.num,
            t.hash,
            t.prev,
            t.created_at
        FROM hive.%s_context_data_view c,
        LATERAL ( SELECT hb.num,
            hb.hash,
            hb.prev,
            hb.created_at
           FROM hive.blocks hb
          WHERE hb.num <= c.min_block
        UNION ALL
         SELECT hbr.num,
            hbr.hash,
            hbr.prev,
            hbr.created_at
           FROM hive.blocks_reversible hbr
           JOIN
           (
             SELECT rb.num, MAX(rb.fork_id) AS max_fork_id
             FROM hive.blocks_reversible rb
             WHERE c.reversible_range AND rb.num > c.irreversible_block AND rb.fork_id <= c.fork_id AND rb.num <= c.current_block_num
             GROUP BY rb.num
           ) visible_blks ON visible_blks.num = hbr.num AND visible_blks.max_fork_id = hbr.fork_id

        ) t;
        ;', _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_blocks_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format( 'DROP VIEW hive.%s_blocks_view;', _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_transactions_view;
        CREATE VIEW hive.%s_transactions_view AS
        SELECT t.block_num,
           t.trx_in_block,
           t.trx_hash,
           t.ref_block_num,
           t.ref_block_prefix,
           t.expiration,
           t.signature
        FROM hive.%s_context_data_view c,
        LATERAL
        (
          SELECT ht.block_num,
                   ht.trx_in_block,
                   ht.trx_hash,
                   ht.ref_block_num,
                   ht.ref_block_prefix,
                   ht.expiration,
                   ht.signature
                FROM hive.transactions ht
                WHERE ht.block_num <= c.min_block
                UNION ALL
                SELECT reversible.block_num,
                    reversible.trx_in_block,
                    reversible.trx_hash,
                    reversible.ref_block_num,
                    reversible.ref_block_prefix,
                    reversible.expiration,
                    reversible.signature
                FROM ( SELECT
                    htr.block_num,
                    htr.trx_in_block,
                    htr.trx_hash,
                    htr.ref_block_num,
                    htr.ref_block_prefix,
                    htr.expiration,
                    htr.signature,
                    htr.fork_id
                FROM hive.transactions_reversible htr
                JOIN (
                   SELECT htr2.block_num, MAX(htr2.fork_id) AS max_fork_id
                   FROM hive.transactions_reversible htr2
                   WHERE c.reversible_range AND htr2.block_num > c.irreversible_block AND htr2.fork_id <= c.fork_id AND htr2.block_num <= c.current_block_num
                   GROUP BY htr2.block_num
                ) as forks ON forks.max_fork_id = htr.fork_id AND forks.block_num = htr.block_num
             ) reversible
        ) t
        ;'
    , _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_transactions_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'DROP VIEW hive.%s_transactions_view;', _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'CREATE OR REPLACE VIEW hive.%s_operations_view
         AS
         SELECT t.id,
            t.block_num,
            t.trx_in_block,
            t.op_pos,
            t.op_type_id,
            t.body
          FROM hive.%s_context_data_view c,
          LATERAL 
          (
            SELECT
              ho.id,
              ho.block_num,
              ho.trx_in_block,
              ho.op_pos,
              ho.op_type_id,
              ho.body
              FROM hive.operations ho
              WHERE ho.block_num <= c.min_block
            UNION ALL
              SELECT
                o.id,
                o.block_num,
                o.trx_in_block,
                o.op_pos,
                o.op_type_id,
                o.body
              FROM hive.operations_reversible o
              -- Reversible operations view must show ops comming from newest fork (specific to app-context)
              -- and also hide ops present at earlier forks for given block
              JOIN
              (
                SELECT hor.block_num, MAX(hor.fork_id) as max_fork_id
                FROM hive.operations_reversible hor
                WHERE c.reversible_range AND hor.block_num > c.irreversible_block AND hor.fork_id <= c.fork_id AND hor.block_num <= c.current_block_num
                GROUP by hor.block_num
              ) visible_ops on visible_ops.block_num = o.block_num and visible_ops.max_fork_id = o.fork_id
        ) t
        ;', _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_operations_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'DROP VIEW hive.%s_operations_view;', _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
    'DROP VIEW IF EXISTS hive.%s_TRANSACTIONS_MULTISIG_VIEW;
    CREATE VIEW hive.%s_TRANSACTIONS_MULTISIG_VIEW
    AS
    SELECT
          t.trx_hash
        , t.signature
    FROM hive.%s_context_data_view c,
    LATERAL(
        SELECT
                  htm.trx_hash
                , htm.signature
        FROM hive.transactions_multisig htm
        JOIN hive.transactions ht ON ht.trx_hash = htm.trx_hash
        WHERE ht.block_num <= c.min_block
        UNION ALL
        SELECT
               reversible.trx_hash
             , reversible.signature
        FROM (
            SELECT
                   htmr.trx_hash
                 , htmr.signature
            FROM hive.transactions_multisig_reversible htmr
            JOIN (
                    SELECT htr.trx_hash, forks.max_fork_id
                    FROM hive.transactions_reversible htr
                    JOIN (
                        SELECT htr2.block_num, MAX(htr2.fork_id) AS max_fork_id
                        FROM hive.transactions_reversible htr2
                        WHERE c.reversible_range AND htr2.block_num > c.irreversible_block AND htr2.fork_id <= c.fork_id AND htr2.block_num <= c.current_block_num
                        GROUP BY htr2.block_num
                    ) as forks ON forks.max_fork_id = htr.fork_id AND forks.block_num = htr.block_num
            ) as trr ON trr.trx_hash = htmr.trx_hash AND trr.max_fork_id = htmr.fork_id
        ) reversible
        ) t;'
        , _context_name, _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_signatures_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    EXECUTE format( 'DROP VIEW hive.%s_TRANSACTIONS_MULTISIG_VIEW;', _context_name );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.create_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format(
        'DROP VIEW IF EXISTS hive.%s_accounts_view;
        CREATE VIEW hive.%s_accounts_view AS
        SELECT
           t.block_num,
           t.id,
           t.name
        FROM hive.%s_context_data_view c,
        LATERAL
        (
          SELECT ha.block_num,
                 ha.id,
                 ha.name
                FROM hive.accounts ha
                WHERE ha.block_num <= c.min_block
                UNION ALL
                SELECT
                    reversible.block_num,
                    reversible.id,
                    reversible.name
                FROM ( SELECT
                    har.block_num,
                    har.id,
                    har.name,
                    har.fork_id
                FROM hive.accounts_reversible har
                JOIN (
                   SELECT har2.block_num, MAX(har2.fork_id) AS max_fork_id
                   FROM hive.accounts_reversible har2
                   WHERE c.reversible_range AND har2.block_num > c.irreversible_block AND har2.fork_id <= c.fork_id AND har2.block_num <= c.current_block_num
                   GROUP BY har2.block_num
                ) as forks ON forks.max_fork_id = har.fork_id AND forks.block_num = har.block_num
             ) reversible
        ) t
        ;'
    , _context_name, _context_name, _context_name
    );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.drop_accounts_view( _context_name TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
EXECUTE format( 'DROP VIEW hive.%s_accounts_view;', _context_name );
END;
$BODY$
;