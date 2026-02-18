{{ config(materialized='raw_sql') }}

-- Depends on: {{ ref('freeze_inventory') }}

UPDATE {{ ref('live_inventory') }}
SET quantity = 600
WHERE item_name = 'Widget B';

-- Part 2 Complete
