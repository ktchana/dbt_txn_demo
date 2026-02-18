# dbt Transaction Demo (BigQuery)

This is a demonstration project showing how to use `dbt` and **BigQuery Scripting** to perform multi-step database transactions (like a bank transfer) safely.

## Overview

In standard SQL analytics, models usually create brand new tables or views (`SELECT ...`). However, sometimes you need to update existing rows in place, and you need to ensure that multiple updates either **all succeed** or **all fail** together.

This project demonstrates how to achieve this using a custom dbt materialization.

## Key Components

1.  **Seed Data (`seeds/bank_accounts.csv`)**:
    *   Creates a small initial dataset representing bank balances for Alice (`id=1`, start balance \$1000) and Bob (`id=2`, start balance \$500).

2.  **Custom Materialization (`macros/raw_sql.sql`)**:
    *   Defines a new materialization type called `raw_sql` strictly for the BigQuery adapter.
    *   Instead of wrapping your model code in a `CREATE TABLE` or `CREATE VIEW` statement, this materialization grabs the raw text from your model file and passes it directly to BigQuery to execute as a script.

3.  **The Transaction Model (`models/transfer_money.sql`)**:
    *   Configured to use the custom materialization: `{{ config(materialized='raw_sql') }}`.
    *   Uses a BigQuery procedural block (`BEGIN ... END;`).
    *   Starts a transaction (`BEGIN TRANSACTION;`).
    *   Executes two operations: deducting $100 from Alice, and adding $100 to Bob.
    *   Commits the changes (`COMMIT TRANSACTION;`) *only* if both updates succeed.
    *   Includes an error handler (`EXCEPTION WHEN ERROR THEN ROLLBACK TRANSACTION;`) to undo any partial changes if the script fails midway through.

---

## Technical Design: BigQuery Scripting in dbt

To perform multi-statement, atomic updates, we must bridge the gap between BigQuery's procedural capabilities and dbt's paradigm. 

**The Limitation of Standard dbt**
By default, dbt wraps all model SQL inside DDL statements like `CREATE OR REPLACE TABLE ... AS ( ... )`. If you write a `BEGIN TRANSACTION` block in a standard dbt model, the generated BigQuery statement becomes `CREATE TABLE AS (BEGIN TRANSACTION; ... )`, which is invalid syntax and fails immediately.

**The `raw_sql` Materialization**
To bypass this limitation, we created `macros/raw_sql.sql`. This custom materialization simply takes the raw `.sql` file contents and executes it directly against BigQuery using `{% call statement('main') %}`. It explicitly skips the `CREATE TABLE` wrapping step entirely.

**The Transaction Logic**
With `raw_sql` established, we can write pure BigQuery Scripting inside `models/transfer_money.sql`.
*   We use a `BEGIN...EXCEPTION...END` block to handle control flow.
*   We explicitly declare `BEGIN TRANSACTION;`.
*   We run multiple `UPDATE` statements sequentially.
*   If *every* statement succeeds, we reach `COMMIT TRANSACTION`, and all changes are permanently saved to the destination tables atomically. 
*   If *any* statement fails (e.g., due to a constraint violation or syntax error), execution immediately jumps to the `EXCEPTION` block. The `ROLLBACK TRANSACTION;` command fires, completely reverting all partial changes made by preceding statements in the block.
*   Finally, we do a `RAISE` inside the exception handler so dbt registers the run as a "Failed" task instead of a silent success.

---

## How to Run the Demo

### Prerequisites

Ensure you have dbt installed for BigQuery:
```bash
pip install dbt-bigquery
```

1.  **Setup your Profile:**
    *   Ensure your `~/.dbt/profiles.yml` has a profile named `dbt_txn_demo` configured for your BigQuery project.
    *   Example `~/.dbt/profiles.yml`:
    ```yaml
    dbt_txn_demo:
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
          location: europe-west2 # Must match the location of your BigQuery dataset
          priority: interactive
    ```

2.  **Load the Seed Data:**
    *   Run `dbt seed` to create the initial `bank_accounts` table in your dataset.

3.  **Execute the Transfer:**
    *   Run `dbt run --select transfer_money` to execute the transaction script.

## Verification

After running the transfer, you can query your BigQuery dataset to verify the balances have updated:

```sql
SELECT * FROM `your_project.your_dataset.bank_accounts` ORDER BY id;
```
Expected result: Alice should have 900, Bob should have 600.
