# dbt BigQuery Concurrency & Isolation Demos

This repository contains two separate dbt projects designed to demonstrate advanced concepts for managing database concurrency, transactions, and read-isolation when using dbt with Google BigQuery.

Analytics engineering doesn't typically require explicit transaction management (`BEGIN` / `COMMIT`), as most dbt models are atomic `CREATE OR REPLACE TABLE` operations. However, when building complex internal data applications, incrementally updating massive live tables, or executing multi-step procedural logic, you need strategies to ensure data integrity and prevent end-users from reading partially updated states.

These two projects demonstrate two distinct patterns for solving these challenges.

---

## Project 1: `dbt_txn_demo` (Procedural Script Transactions)

**Goal:** Execute multiple data mutations (e.g., deducting from one account and adding to another) and guarantee that either *all* of them succeed or *none* of them succeed.

**The Strategy:** 
BigQuery supports multi-statement transactional scripts. This project uses a custom dbt materialization (`raw_sql`) to pass an entire procedural script—containing `BEGIN TRANSACTION` and `COMMIT TRANSACTION` blocks—directly to the database, bypassing standard dbt SQL wrapping.

**Key Learnings:**
*   How to build custom materializations for non-standard use cases.
*   How to structure `UPDATE` statements inside BigQuery transactions safely within dbt.
*   How to handle rollbacks and raise errors correctly back to the dbt runner if a step fails.

-> [View the `dbt_txn_demo` README](./dbt_txn_demo/README.md) for full setup instructions.

---

## Project 2: `dbt_view_time_travel_demo` (Snapshot Isolation)

**Goal:** Perform long-running, multi-step updates on a live table *without* exposing the dirty, mid-update state to end-users querying a public view.

**The Strategy:**
BigQuery features "Time Travel" via the `FOR SYSTEM_TIME AS OF` clause. Before running the updates, this project uses a custom `no_op` materialization and dbt hooks to "freeze" a public-facing view to the exact current timestamp. End-users querying the view will see a consistent, frozen snapshot. Meanwhile, dbt runs the intensive updates on the underlying table. Once complete, another hook "thaws" the view, returning it to point at the live, fully updated table natively.

**Key Learnings:**
*   How to utilize BigQuery Time Travel within dynamic dbt schema automation.
*   How to use the `no_op` materialization pattern to execute `pre_hook` and `post_hook` logic to orchestrate views without polluting the dataset with unnecessary artifacts.
*   How to enforce DAG execution order for non-SQL operations using dbt comment-refs (`-- Depends on: {{ ref(...) }}`).

-> [View the `dbt_view_time_travel_demo` README](./dbt_view_time_travel_demo/README.md) for full setup instructions.
