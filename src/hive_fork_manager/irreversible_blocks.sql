CREATE TABLE IF NOT EXISTS hive.blocks (
       num integer NOT NULL,
       hash bytea NOT NULL,
       prev bytea NOT NULL,
       created_at timestamp without time zone NOT NULL,
       CONSTRAINT pk_hive_blocks PRIMARY KEY( num )
);

CREATE TABLE IF NOT EXISTS hive.irreversible_data (
      id integer,
      consistent_block integer,
      CONSTRAINT pk_irreversible_data PRIMARY KEY ( id ),
      CONSTRAINT fk_1_hive_irreversible_data FOREIGN KEY (consistent_block) REFERENCES hive.blocks (num)
);

INSERT INTO hive.irreversible_data VALUES(1,NULL) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS hive.transactions (
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash ),
    CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_num) REFERENCES hive.blocks (num)
);

CREATE TABLE IF NOT EXISTS hive.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature ),
    CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hive.transactions (trx_hash)
);

CREATE TABLE IF NOT EXISTS hive.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS hive.operations (
    id bigint not null,
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    op_type_id smallint NOT NULL,
    -- timestamp: Specific to operation kind.  It may be set for block time -3s (current hived head_block_time)
    -- or for **next**  block time (when hived node finished evaluation of current block).
    -- This behavior depends on hived implementation, and **this logic should not be** repeated HAF-client app side. Specifically:
    -- - regular user operations put into transactions got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - fork and schedule operations got head_block_time: -3s ( time of block predecessing currently applied block )
    -- - system triggered virtual operations usualy are created after applaying current block and got time equals its time
    --   (after hived not changed head_block to another one)
    timestamp TIMESTAMP NOT NULL,
    body text DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id ),
    CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_num) REFERENCES hive.blocks(num),
    CONSTRAINT fk_2_hive_operations FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id)
);

CREATE INDEX IF NOT EXISTS hive_transactions_block_num_trx_in_block_idx ON hive.transactions ( block_num, trx_in_block );
CREATE INDEX IF NOT EXISTS hive_operations_block_num_type_trx_in_block_idx ON hive.operations ( block_num, op_type_id, trx_in_block );
