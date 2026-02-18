{{ config(materialized='raw_sql') }}

UPDATE {{ ref('live_inventory') }}
SET quantity = 500
WHERE item_name = 'Widget A';

-- Part 1 Complete
