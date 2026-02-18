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

## How to Run the Demo

1.  **Setup your Profile:**
    *   Ensure your `~/.dbt/profiles.yml` has a profile named `dbt_txn_demo` configured for your BigQuery project.

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
