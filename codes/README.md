----------------
SQL - Postgress
---------------
This SQL script provides a production-grade schema for your HTAP framework in PostgreSQL. It is architected to handle multi-tenant branches, multi-technician task assignments, and strict audit trails for 21 CFR Part 11 compliance.

Key Architectural Features Included:
Audit Triggers: Automatically captures every change in a JSON-based shadow table.

Relational Integrity: Strict Foreign Keys linking Organizations (Branches/Distributors), Assets, and Users.

Compliance Logic: Stored procedures to ensure a device cannot be dispatched without a signed QA check.

Deployment: You can run this directly in pgAdmin or a PostgreSQL CLI.

Verification: Try updating a service_orders stage to 'Dispatched' without adding a row to compliance_checks; the trigger will block it, proving your architecture enforces safety.


-----------------
For Python file
-----------------

This Python script uses the faker and psycopg2 libraries to populate your PostgreSQL schema with 1,000 realistic service records, including multi-branch distribution and audit logs.

Prerequisites
You will need to install the following libraries if you haven't already: pip install psycopg2-binary faker
