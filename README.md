# Tesla Dealership Database

This repository includes:
- A single `setup.sql` with the full schema and sample data (base + expanded + Part 4).
- Web Front-End (Flask app).
- Advanced features (array + text search + trigger).

## Install and Setup (Local)

### 1) Prerequisites
- PostgreSQL 12+ installed locally.
- Python 3.9+.

### 2) Create database
```sql
CREATE DATABASE tesla_db;
```

### 3) One-step install (all schema + data)
```powershell
psql -U <user> -d tesla_db -f setup.sql
```

## Web App (Part 3 Web Front-End)

### Install dependencies
```powershell
pip install -r requirements.txt
```

### Set DB connection and run
```powershell
$env:DATABASE_URI = "postgresql://USERNAME:PASSWORD@localhost:5432/tesla_db"
python server.py
```

Open http://127.0.0.1:5000/

## What the Database Supports

### Core Features
- Manage customers and dealerships.
- Track employees by dealership.
- Manage Tesla models and individual vehicles (VIN, price, features, availability).
- Record sales, payments, and test drives.
- Schedule service appointments and collect reviews.

### Expanded Design
- Financing: lenders, plans, and loans tied to sales.
- Trade-ins associated with sales.
- Inventory transfers between dealerships.
- Service billing: invoices and line items.

#### Expanded Design Notes
- `loans.sale_id` and `trade_ins.sale_id` are UNIQUE (max one loan/trade-in per sale).
- `inventory_transfers` enforces different from/to dealerships with a CHECK.
- `service_invoices.service_id` is UNIQUE (one invoice per appointment).
- `service_items` are line items tied to an invoice.

### Advanced Features 
- Array attribute: `models.trim_packages`.
- Full-text search on `service_appointments.service_notes`.
- Trigger: auto-mark vehicles as unavailable after a sale.

#### Triggers
```sql
INSERT INTO sales (vin, customer_id, employee_id, sale_date, sale_price)
VALUES ('5YJ3E1EA7JF000002', 2, 2, '2023-08-01', 33990.00);
```

```sql
SELECT vin, available FROM vehicles WHERE vin = '5YJ3E1EA7JF000002';
```

Expected outcome: `available` becomes `FALSE` for that VIN.

#### Queries
```sql
SELECT service_id, vin, service_date, service_type, service_notes
FROM service_appointments
WHERE service_notes_tsv @@ to_tsquery('battery & diagnostics');
```

```sql
SELECT model_name, trim_packages
FROM models
WHERE 'Plaid' = ANY (trim_packages);
```

## Using the Web App

### Browse and manage inventory
- Vehicles page: filter by model, dealership, availability.
- Vehicle detail page: reviews + service history.

### Record activity
- Add Review: insert customer reviews for a VIN.
- Record Sale: insert a sale and mark the vehicle unavailable (via trigger).
- Schedule Service: create a service appointment.

### Expanded design workflows
- Financing: view lenders and plans.
- Loans: view and add loans tied to sales.
- Trade-Ins: view and add trade-in records.
- Transfers: view and add inventory transfers.
- Service Invoices: view invoices and line items; add service items.

## Notes
- `setup.sql` drops and recreates all tables, then loads sample data.
