{{ config(materialized='raw_sql') }}

-- Start the BigQuery Scripting block
BEGIN
    -- Start the database transaction
    BEGIN TRANSACTION;
-- Step 1: Deduct $100 from Alice (id=1)
UPDATE {{ ref('bank_accounts') }}
SET balance = balance - 100
WHERE id = 1;

-- Step 2: Add $100 to Bob (id=2)
UPDATE {{ ref('bank_accounts') }}
SET balance = balance + 100
WHERE id = 2;

-- Commit the changes if both updates succeeded
COMMIT TRANSACTION;

-- Handle errors: If anything failed, undo everything
EXCEPTION WHEN ERROR THEN
ROLLBACK TRANSACTION;
RAISE USING MESSAGE = @@error.message; -- Fail the dbt run
END;
