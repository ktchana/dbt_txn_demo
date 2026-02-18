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

## Technical Design: Control Models & DAG Dependencies

**The Freeze and Thaw Logic (Time Travel)**
The core magic of this demo relies on BigQuery's Time Travel capabilities (`FOR SYSTEM_TIME AS OF`). 
*   **Freeze (`freeze_view` macro):** When executed, this macro dynamically polls BigQuery for the `CURRENT_TIMESTAMP()`. It then runs a `CREATE OR REPLACE VIEW` statement that permanently hardcodes that exact timestamp into the view's SQL definition. Anyone querying this view is now looking at historical data frozen at that moment, completely immune to any subsequent updates we run on the underlying table.
*   **Thaw (`thaw_view` macro):** Once our messy, multi-step updates are fully complete, this macro executes another `CREATE OR REPLACE VIEW`. This time, it strips away the `FOR SYSTEM_TIME AS OF` clause. The view instantly reverts to being a standard, pass-through view, and the fully updated, consistent data is atomically exposed to end-users.

To automate this workflow securely within a single `dbt run` command, we must force dbt to execute the freeze, the updates, and the thaw in a very specific order. However, neither the lock processes nor the update processes create standard tables or views that can be `ref`-ed within standard SQL.

**The `no_op` Materialization**
The `freeze_inventory` and `thaw_inventory` models aren't creating data; they are executing BigQuery DDL (via our macros) purely for control flow. If we materialized these as standard `view`s, dbt would pollute the dataset by generating empty, useless views. 
To solve this, we use a custom `no_op` materialization (`macros/no_op.sql`). This tells dbt to run our `post_hook` logic (the time travel macros) but completely skip creating any database object.

**Enforcing the DAG with Comment-Refs**
Because `no_op` and `raw_sql` models don't build queryable relations, we cannot use `SELECT * FROM {{ ref('freeze_inventory') }}` in our SQL to force a dependency. BigQuery would throw a "Table Not Found" error.
Instead, we place dbt `ref()` calls inside SQL comments at the top of the files:
```sql
-- Depends on: {{ ref('freeze_inventory') }}
```
*   **dbt's perspective:** It parses the Jinja before sending anything to the database, sees the `ref()`, and understands that this model *must* wait for `freeze_inventory` to finish.
*   **BigQuery's perspective:** It receives the final compiled SQL, sees a harmless comment, ignores it, and perfectly executes the `UPDATE` statement below it.

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

### 3. Run the Demo

You can execute the demo in two different ways depending on what you want to test.

#### Option 1: Automated DAG Execution (Recommended)
This method relies on dbt's built-in dependency management. We have configured `freeze_inventory` to run first, followed by the two update scripts, and finally `thaw_inventory`.

Run the entire pipeline in one command:
```bash
dbt run
```
**What happens:**
1. dbt runs `freeze_inventory`, which takes a snapshot of the current time and locks `public_inventory` to that timestamp.
2. dbt runs `update_part_1` and `update_part_2` (potentially in parallel), modifying the base `live_inventory` table behind the scenes.
3. dbt runs `thaw_inventory`, which removes the time-travel clause, instantly exposing the fully updated table to end-users atomically.

#### Option 2: Step-by-Step Manual Execution
This method allows you to query the database mid-transaction to truly prove that users are isolated from partial updates.

**Step A: Freeze the View**
Lock the public view to the current time:
```bash
dbt run --select freeze_inventory
```
*Wait 10-20 seconds before proceeding to ensure BigQuery's time travel buffer captures the change state clearly.*

**Step B: Execute the Updates**
Run our partial updates on the underlying `live_inventory` table:
```bash
dbt run --select update_part_1
dbt run --select update_part_2
```
*Proof of Isolation:* If you query `public_inventory` right now, you will still see the old values (100 and 200) because the view is frozen to the past! The underlying `live_inventory` table, however, has Widget A at 500 and Widget B at 600.

**Step C: Thaw the View**
Now that updates are complete, restore the view to point to the live table:
```bash
dbt run --select thaw_inventory
```
*Result:* Querying `public_inventory` will now show the new, fully updated values (500 and 600) together.
