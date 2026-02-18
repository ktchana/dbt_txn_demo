{{ config(
    materialized='no_op',
    post_hook=[
      "{{ thaw_view('public_inventory', 'live_inventory') }}"
    ]
) }}

-- Depends on: {{ ref('update_part_1') }}, {{ ref('update_part_2') }}

SELECT 1 as id
