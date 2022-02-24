CREATE SCHEMA function_propagation_schema;
SET search_path TO 'function_propagation_schema';

-- Check whether supported dependencies can be distributed while propagating functions

-- Check types
SET citus.enable_metadata_sync TO OFF;
    CREATE TYPE function_prop_type AS (a int, b int);
RESET citus.enable_metadata_sync;

CREATE OR REPLACE FUNCTION func_1(param_1 function_prop_type)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

-- Check all dependent objects and function depends on all nodes
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema'::regnamespace::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.function_prop_type'::regtype::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_1'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema'::regnamespace::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.function_prop_type'::regtype::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_1'::regproc::oid;$$) ORDER BY 1,2;

SET citus.enable_metadata_sync TO OFF;
    CREATE TYPE function_prop_type_2 AS (a int, b int);
RESET citus.enable_metadata_sync;

CREATE OR REPLACE FUNCTION func_2(param_1 int)
RETURNS function_prop_type_2
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.function_prop_type_2'::regtype::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_2'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.function_prop_type_2'::regtype::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_2'::regproc::oid;$$) ORDER BY 1,2;

-- Have a separate check for type created in transaction
BEGIN;
    CREATE TYPE function_prop_type_3 AS (a int, b int);
COMMIT;

-- Objects in the body part is not found as dependency
CREATE OR REPLACE FUNCTION func_3(param_1 int)
RETURNS int
LANGUAGE plpgsql AS
$$
DECLARE
    internal_param1 function_prop_type_3;
BEGIN
    return 1;
END;
$$;

SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.function_prop_type_3'::regtype::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_3'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_3'::regproc::oid;$$) ORDER BY 1,2;

-- Check table
CREATE TABLE function_prop_table(a int, b int);

-- Non-distributed table is not distributed as dependency
CREATE OR REPLACE FUNCTION func_4(param_1 function_prop_table)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

CREATE OR REPLACE FUNCTION func_5(param_1 int)
RETURNS function_prop_table
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

-- Functions can be created with distributed table dependency
SELECT create_distributed_table('function_prop_table', 'a');
CREATE OR REPLACE FUNCTION func_6(param_1 function_prop_table)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_6'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_6'::regproc::oid;$$) ORDER BY 1,2;

-- Views are not supported
CREATE VIEW function_prop_view AS SELECT * FROM function_prop_table;
CREATE OR REPLACE FUNCTION func_7(param_1 function_prop_view)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

CREATE OR REPLACE FUNCTION func_8(param_1 int)
RETURNS function_prop_view
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

-- Check within transaction
BEGIN;
    CREATE TYPE type_in_transaction AS (a int, b int);
    CREATE OR REPLACE FUNCTION func_in_transaction(param_1 type_in_transaction)
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    -- Within transaction functions are not distributed
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.type_in_transaction'::regtype::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction'::regproc::oid;
COMMIT;

-- Show that recreating it outside transaction distributes the function and dependencies
CREATE OR REPLACE FUNCTION func_in_transaction(param_1 type_in_transaction)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.type_in_transaction'::regtype::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.type_in_transaction'::regtype::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction'::regproc::oid;$$) ORDER BY 1,2;

-- Test for SQL function with unsupported object in function body
CREATE TABLE table_in_sql_body(id int);

CREATE FUNCTION max_of_table()
RETURNS int
LANGUAGE SQL AS
$$
    SELECT max(id) FROM table_in_sql_body
$$;

-- Show that only function has propagated, since the table is not resolved as dependency
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.type_in_transaction'::regclass::oid;
SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.max_of_table'::regproc::oid;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.max_of_table'::regproc::oid;$$) ORDER BY 1,2;

-- Check extension owned table
CREATE TABLE extension_owned_table(a int);
SELECT run_command_on_workers($$
CREATE TABLE function_propagation_schema.extension_owned_table(a int);
$$
);
CREATE EXTENSION seg;
ALTER EXTENSION seg ADD TABLE extension_owned_table;
SELECT run_command_on_workers($$
ALTER EXTENSION seg ADD TABLE function_propagation_schema.extension_owned_table;
$$);

CREATE OR REPLACE FUNCTION func_for_ext_check(param_1 extension_owned_table)
RETURNS int
LANGUAGE plpgsql AS
$$
BEGIN
    return 1;
END;
$$;

-- Show that functions are propagated (or not) as a dependency

-- Function as a default column
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_def()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    -- Function shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def'::regproc::oid;

    CREATE TABLE table_to_prop_func(id int, col_1 int default func_in_transaction_def());
    SELECT create_distributed_table('table_to_prop_func','id');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def'::regproc::oid;$$) ORDER BY 1,2;


-- Multiple functions as a default column
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_1()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    CREATE OR REPLACE FUNCTION func_in_transaction_2()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_1'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_2'::regproc::oid;

    CREATE TABLE table_to_prop_func_2(id int, col_1 int default func_in_transaction_1() + func_in_transaction_2());
    SELECT create_distributed_table('table_to_prop_func_2','id');

    -- Functions should be marked as distribued after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_1'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_2'::regproc::oid;
COMMIT;

-- Functions should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_1'::regproc::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_2'::regproc::oid;$$) ORDER BY 1,2;


-- If function has dependency on non-distributed table it should error out
BEGIN;
    CREATE TABLE non_dist_table(id int);

    CREATE OR REPLACE FUNCTION func_in_transaction_3(param_1 non_dist_table)
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    CREATE TABLE table_to_prop_func_3(id int, col_1 int default func_in_transaction_3(NULL::non_dist_table));

    -- It should error out as there is a non-distributed table dependency
    SELECT create_distributed_table('table_to_prop_func_3','id');
COMMIT;


-- Adding a column with default value should propagate the function
BEGIN;
    CREATE TABLE table_to_prop_func_4(id int);
    SELECT create_distributed_table('table_to_prop_func_4', 'id');

    CREATE OR REPLACE FUNCTION func_in_transaction_4()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    -- Function shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_4'::regproc::oid;

    ALTER TABLE table_to_prop_func_4 ADD COLUMN col_1 int default function_propagation_schema.func_in_transaction_4();

    -- Function should be marked as distributed after adding the column
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_4'::regproc::oid;
COMMIT;

-- Functions should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_4'::regproc::oid;$$) ORDER BY 1,2;


-- Adding multiple columns with default values should propagate the function
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_5()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    CREATE OR REPLACE FUNCTION func_in_transaction_6()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;


    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_5'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_6'::regproc::oid;

    CREATE TABLE table_to_prop_func_5(id int, col_1 int default func_in_transaction_5(), col_2 int default func_in_transaction_6());
    SELECT create_distributed_table('table_to_prop_func_5', 'id');

    -- Functions should be marked as distributed after adding the column
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_5'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_6'::regproc::oid;
COMMIT;

-- Functions should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_5'::regproc::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_6'::regproc::oid;$$) ORDER BY 1,2;

-- Adding a constraint with function check should propagate the function
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_7(param_1 int)
    RETURNS boolean
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return param_1 > 5;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_7'::regproc::oid;

    CREATE TABLE table_to_prop_func_6(id int, col_1 int check (function_propagation_schema.func_in_transaction_7(col_1)));
    SELECT create_distributed_table('table_to_prop_func_6', 'id');

    -- Function should be marked as distributed after adding the column
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_7'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_7'::regproc::oid;$$) ORDER BY 1,2;


-- Adding a constraint with multiple functions check should propagate the function
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_8(param_1 int)
    RETURNS boolean
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return param_1 > 5;
    END;
    $$;

    CREATE OR REPLACE FUNCTION func_in_transaction_9(param_1 int)
    RETURNS boolean
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return param_1 > 5;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_8'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_9'::regproc::oid;

    CREATE TABLE table_to_prop_func_7(id int, col_1 int check (function_propagation_schema.func_in_transaction_8(col_1) and function_propagation_schema.func_in_transaction_9(col_1)));
    SELECT create_distributed_table('table_to_prop_func_7', 'id');

    -- Function should be marked as distributed after adding the column
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_8'::regproc::oid;
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_9'::regproc::oid;
COMMIT;

-- Functions should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_8'::regproc::oid;$$) ORDER BY 1,2;
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_9'::regproc::oid;$$) ORDER BY 1,2;


-- Adding a column with constraint should propagate the function
BEGIN;
    CREATE TABLE table_to_prop_func_8(id int, col_1 int);
    SELECT create_distributed_table('table_to_prop_func_8', 'id');

    CREATE OR REPLACE FUNCTION func_in_transaction_10(param_1 int)
    RETURNS boolean
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return param_1 > 5;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_10'::regproc::oid;

    ALTER TABLE table_to_prop_func_8 ADD CONSTRAINT col1_check CHECK (function_propagation_schema.func_in_transaction_10(col_1));

    -- Function should be marked as distributed after adding the constraint
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_10'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_10'::regproc::oid;$$) ORDER BY 1,2;


-- If constraint depends on a non-distributed table it should error out
BEGIN;
    CREATE TABLE local_table_for_const(id int);

    CREATE OR REPLACE FUNCTION func_in_transaction_11(param_1 int, param_2 local_table_for_const)
    RETURNS boolean
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return param_1 > 5;
    END;
    $$;

    CREATE TABLE table_to_prop_func_9(id int, col_1 int check (func_in_transaction_11(col_1, NULL::local_table_for_const)));

    -- It should error out since there is non-distributed table dependency exists
    SELECT create_distributed_table('table_to_prop_func_9', 'id');
COMMIT;


-- Show that function as a part of generated always is supporte
BEGIN;

	CREATE OR REPLACE FUNCTION non_sense_func_for_generated_always()
	RETURNS int
	LANGUAGE plpgsql IMMUTABLE AS
	$$
	BEGIN
	    return 1;
	END;
	$$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.non_sense_func_for_generated_always'::regproc::oid;

	CREATE TABLE people (
	id int,
    height_cm numeric,
    height_in numeric GENERATED ALWAYS AS (height_cm / non_sense_func_for_generated_always()) STORED);

    SELECT create_distributed_table('people', 'id');

     -- Show that function is distributed after distributing the table
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.non_sense_func_for_generated_always'::regproc::oid;
COMMIT;


-- Show that functions depending table via rule are also distributed
BEGIN;
    CREATE OR REPLACE FUNCTION func_for_rule()
    RETURNS int
    LANGUAGE plpgsql STABLE AS
    $$
    BEGIN
        return 4;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_rule'::regproc::oid;

    CREATE TABLE table_1_for_rule(id int, col_1 int);
    CREATE TABLE table_2_for_rule(id int, col_1 int);

    CREATE RULE rule_1 AS ON UPDATE TO table_1_for_rule DO ALSO UPDATE table_2_for_rule SET col_1 = col_1 * func_for_rule();

    SELECT create_distributed_table('table_1_for_rule','id');

    -- Functions should be distributed after distributing the table
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_rule'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_rule'::regproc::oid;$$) ORDER BY 1,2;


-- Show that functions as partitioning functions are supported
BEGIN;

	CREATE OR REPLACE FUNCTION non_sense_func_for_partitioning(int)
	RETURNS int
	LANGUAGE plpgsql IMMUTABLE AS
	$$
	BEGIN
	    return 1;
	END;
	$$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.non_sense_func_for_partitioning'::regproc::oid;

    CREATE TABLE partitioned_table_to_test_func_prop(id INT, a INT) PARTITION BY RANGE (non_sense_func_for_partitioning(id));

    SELECT create_distributed_table('partitioned_table_to_test_func_prop', 'id');

     -- Show that function is distributed after distributing the table
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.non_sense_func_for_partitioning'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.non_sense_func_for_partitioning'::regproc::oid;$$) ORDER BY 1,2;


-- Test function dependency on citus local table
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_for_local_table()
    RETURNS int
    LANGUAGE plpgsql AS
    $$
    BEGIN
        return 1;
    END;
    $$;

    -- Function shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_for_local_table'::regproc::oid;

    CREATE TABLE citus_local_table_to_test_func(l1 int DEFAULT func_in_transaction_for_local_table());
    SELECT 1 FROM master_add_node('localhost', :master_port, groupid => 0);
    SELECT citus_add_local_table_to_metadata('citus_local_table_to_test_func');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_for_local_table'::regproc::oid;
ROLLBACK;

-- Show that having a function dependency on exlude also works
BEGIN;
    CREATE OR REPLACE FUNCTION exclude_bool_func()
    RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE AS
    $$
    BEGIN
        return true;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.exclude_bool_func'::regproc::oid;

    CREATE TABLE exclusion_func_prop_table (id int, EXCLUDE USING btree (id WITH =) WHERE (exclude_bool_func()));
    SELECT create_distributed_table('exclusion_func_prop_table', 'id');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.exclude_bool_func'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.exclude_bool_func'::regproc::oid;$$) ORDER BY 1,2;


-- Show that having a function dependency for index also works
BEGIN;
    CREATE OR REPLACE FUNCTION func_for_index_predicate(col_1 int)
    RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE AS
    $$
    BEGIN
        return col_1 > 5;
    END;
    $$;

    -- Functions shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_index_predicate'::regproc::oid;

    CREATE TABLE table_to_check_func_index_dep (id int, col_2 int);
    CREATE INDEX on table_to_check_func_index_dep(col_2) WHERE (func_for_index_predicate(col_2));

    SELECT create_distributed_table('table_to_check_func_index_dep', 'id');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_index_predicate'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_index_predicate'::regproc::oid;$$) ORDER BY 1,2;


-- Test function to function dependency
BEGIN;
    CREATE OR REPLACE FUNCTION func_for_func_dep_1()
    RETURNS int
    LANGUAGE plpgsql IMMUTABLE AS
    $$
    BEGIN
        return 5;
    END;
    $$;

    CREATE TABLE func_dep_table(a int, b int default func_for_func_dep_1());

    CREATE OR REPLACE FUNCTION func_for_func_dep_2(col_1 func_dep_table)
    RETURNS int
    LANGUAGE plpgsql IMMUTABLE AS
    $$
    BEGIN
        return 5;
    END;
    $$;

    SELECT create_distributed_table('func_dep_table', 'a');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_func_dep_1'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_for_func_dep_1'::regproc::oid;$$) ORDER BY 1,2;


-- Test function with SQL language and sequence dependency
BEGIN;
    CREATE OR REPLACE FUNCTION func_in_transaction_def_with_seq(val bigint)
    RETURNS bigint
    LANGUAGE SQL AS
    $$
    SELECT 2 * val;
    $$;

    CREATE OR REPLACE FUNCTION func_in_transaction_def_with_func(val bigint)
    RETURNS bigint
    LANGUAGE SQL AS
    $$
    SELECT func_in_transaction_def_with_seq(val);
    $$;

    -- Function shouldn't be propagated within transaction
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def_with_seq'::regproc::oid;

    CREATE SEQUENCE myseq;
    CREATE TABLE table_to_prop_seq_func(id int, col_1 bigint default func_in_transaction_def_with_func(func_in_transaction_def_with_seq(nextval('myseq'))));

    SELECT create_distributed_table('table_to_prop_seq_func','id');

    -- Function should be marked as distributed after distributing the table that depends on it
    SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def_with_seq'::regproc::oid;
COMMIT;

-- Function should be marked as distributed on the worker after committing changes
SELECT * FROM run_command_on_workers($$SELECT pg_identify_object_as_address(classid, objid, objsubid) from citus.pg_dist_object where objid = 'function_propagation_schema.func_in_transaction_def_with_seq'::regproc::oid;$$) ORDER BY 1,2;

RESET search_path;
SET client_min_messages TO WARNING;
DROP SCHEMA function_propagation_schema CASCADE;
