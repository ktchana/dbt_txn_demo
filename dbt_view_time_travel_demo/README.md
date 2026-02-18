# dbt BigQuery Time Travel (Snapshot Isolation) Demo

This project demonstrates how to emulate **Snapshot Isolation** during long-running data transformations in BigQuery using dbt.

## The Problem

When you perform large, multi-step updates on a live database table, end-users querying that table might see inconsistent data (e.g., they might see "Part 1" of the update but not "Part 2").

## The Solution

BigQuery supports "Time Travel", allowing you to query historical data using `FOR SYSTEM_TIME AS OF`. We can use this feature to "freeze" a public-facing view to a specific timestamp just before we begin our long-running updates. 

While the background table is being updated, users querying the public view will continue to see a consistent, point-in-time snapshot. Once the updates are safely completed, we "thaw" the view, pointing it back to the live, fully-updated table.

## Key Components

1.  **Seed Data (`seeds/live_inventory.csv`)**: The source table we will be updating.
2.  **Public View (`models/public_inventory.sql`)**: The view end-users actually query.
3.  **Snapshot Macros (`macros/snapshot_utils.sql`)**:
    *   `freeze_view(view_name, source_table)`: Replaces a view so it points to the source table at the *exact current timestamp*.
    *   `thaw_view(view_name, source_table)`: Replaces the view so it points to the live source table normally.
4.  **Update Models (`models/update_part_1.sql` & `update_part_2.sql`)**: Custom `raw_sql` models simulating a multi-step data mutation.

---

## Step-by-Step Demo Guide

### 1. Prerequisites
Ensure you have the BigQuery adapter installed:
```bash
pip install dbt-bigquery
```

Ensure your `~/.dbt/profiles.yml` is configured correctly. Example:
```yaml
dbt_view_time_travel_demo:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-gcp-project-id
      dataset: your-bigquery-dataset
      threads: 1
      job_execution_timeout_seconds: 300
      job_retries: 1
      location: europe-west2 
      priority: interactive
```

### 2. Initialize the Base Data
Load the starting inventory data and create the initial public view:
```bash
dbt seed
dbt run --select public_inventory
```
*Current State:* Widget A has 100 qty, Widget B has 200 qty.

### 3. Freeze the View (Snapshot Isolation)
Before starting our big updates, lock the public view to the current time:
```bash
dbt run-operation freeze_view --args '{view_name: "public_inventory", source_table: "live_inventory"}'
```
*Wait 10-20 seconds before proceeding to ensure BigQuery's time travel buffer captures the change state clearly.*

### 4. Execute the Multi-Step Update
Run our partial updates on the underlying `live_inventory` table:
```bash
dbt run --select update_part_1
dbt run --select update_part_2
```
*Behind the scenes:* The live table now has Widget A at 500 and Widget B at 600.
*If you query `public_inventory` right now:* You will still see the old values (100 and 200) because the view is frozen! End-users are isolated from the mid-update state.

### 5. Thaw the View
Now that updates are complete, restore the view to point to the live table:
```bash
dbt run-operation thaw_view --args '{view_name: "public_inventory", source_table: "live_inventory"}'
```
*If you query `public_inventory` right now:* You will now see the new, fully updated values (500 and 600). The transaction has been exposed to end-users atomically!
