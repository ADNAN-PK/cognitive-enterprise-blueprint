----------------
1. SQL - Postgress
---------------
This SQL script provides a production-grade schema for your HTAP framework in PostgreSQL. It is architected to handle multi-tenant branches, multi-technician task assignments, and strict audit trails for 21 CFR Part 11 compliance.

Key Architectural Features Included:
  Audit Triggers: Automatically captures every change in a JSON-based shadow table.
  
  Relational Integrity: Strict Foreign Keys linking Organizations (Branches/Distributors), Assets, and Users.
  
  Compliance Logic: Stored procedures to ensure a device cannot be dispatched without a signed QA check.
  
  Deployment: You can run this directly in pgAdmin or a PostgreSQL CLI.
  
  Verification: Try updating a service_orders stage to 'Dispatched' without adding a row to compliance_checks; the trigger will block it, proving your architecture enforces safety.

-------
  1. Connection Prerequisites
  Before running the Python script, ensure your PostgreSQL instance is configured to allow external connections (if not running locally):
  
  Host/Port: Default is usually localhost and 5432.
  
  Database: You must create the database (e.g., CREATE DATABASE medtech_ops;) before running the table creation scripts.
  
  Credentials: You will need a user with CREATE and INSERT permissions.
  
  2. Execution Order
  The order in which you run the files is critical to maintaining relational integrity:
  
  Run the SQL Script First: This creates the schema, the custom ENUM types (like org_type and user_role), and the mandatory triggers.
  
  Run the Python Script Second: The Python script relies on the UUID-based primary keys and relationships established in the SQL file to insert data correctly.
  
  3. User & Role Context
  Your schema includes a user_role ENUM. When you start building your application layer or running manual tests:
  
  QA Logic: Only users with the QA or Manager role should ideally be linked to the compliance_checks table.
  
  Technician Assignment: The repair_jobs table is designed to track "Wrench Time" for specific technicians, which will be essential for your "Labor Utilization" KPIs in Microsoft Fabric.
  
  4. System Safeguards
  Remember that the trg_validate_dispatch trigger is active.
  
  If you try to manually update a service_order to Dispatched without a corresponding entry in compliance_checks where is_passed = TRUE, PostgreSQL will throw an error and block the update.
  
  This is your primary defense for 21 CFR Part 11 compliance—the system literally will not let you ship a device that hasn't been signed off.
-------

-----------------
2. For Python file
-----------------

This Python script uses the faker and psycopg2 libraries to populate your PostgreSQL schema with 1,000 realistic service records, including multi-branch distribution and audit logs.

Prerequisites
You will need to install the following libraries if you haven't already: pip install psycopg2-binary faker
