{{ config(
    materialized='no_op',
    post_hook=[
      "{{ freeze_view('public_inventory', 'live_inventory') }}"
    ]
) }}

SELECT 1 as id
