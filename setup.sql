-- Tesla Dealership Database: Full Setup (Base + Expanded + Part 4)

-- Drop in dependency order
DROP TABLE IF EXISTS service_items CASCADE;
DROP TABLE IF EXISTS service_invoices CASCADE;
DROP TABLE IF EXISTS inventory_transfers CASCADE;
DROP TABLE IF EXISTS trade_ins CASCADE;
DROP TABLE IF EXISTS loans CASCADE;
DROP TABLE IF EXISTS financing_plans CASCADE;
DROP TABLE IF EXISTS lenders CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS service_appointments CASCADE;
DROP TABLE IF EXISTS test_drives CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS models CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS dealerships CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Base schema
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    join_date DATE NOT NULL
);

CREATE TABLE dealerships (
    dealership_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state CHAR(2) NOT NULL,
    CONSTRAINT dealerships_state_check CHECK (state ~ '^[A-Z]{2}$')
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL,
    dealership_id INT NOT NULL,
    CONSTRAINT employees_role_check CHECK (role IN ('Sales Rep','Sales Manager','Service Advisor','Technician')),
    FOREIGN KEY (dealership_id) REFERENCES dealerships(dealership_id)
);

CREATE TABLE models (
    model_id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL UNIQUE,
    base_price NUMERIC(10,2) CHECK (base_price > 0),
    trim_packages TEXT[] NOT NULL DEFAULT '{}'
);

CREATE TABLE vehicles (
    vin CHAR(17) PRIMARY KEY,
    model_id INT NOT NULL,
    dealership_id INT NOT NULL,
    model_year INT CHECK (model_year >= 2015),
    color VARCHAR(30),
    mileage INT CHECK (mileage >= 0),
    price NUMERIC(10,2) CHECK (price > 0),
    available BOOLEAN NOT NULL DEFAULT TRUE,
    features TEXT[] NOT NULL DEFAULT '{}',
    FOREIGN KEY (model_id) REFERENCES models(model_id),
    FOREIGN KEY (dealership_id) REFERENCES dealerships(dealership_id)
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    vin CHAR(17) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    employee_id INT NOT NULL,
    sale_date DATE NOT NULL,
    sale_price NUMERIC(10,2) CHECK (sale_price > 0),
    FOREIGN KEY (vin) REFERENCES vehicles(vin),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    amount NUMERIC(10,2) CHECK (amount > 0),
    payment_date DATE NOT NULL,
    CONSTRAINT payments_method_check CHECK (payment_method IN ('Cash','Check','Credit Card','Bank Transfer','Financing')),
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id)
);

CREATE TABLE test_drives (
    test_drive_id SERIAL PRIMARY KEY,
    vin CHAR(17) NOT NULL,
    customer_id INT NOT NULL,
    employee_id INT NOT NULL,
    drive_date DATE NOT NULL,
    CONSTRAINT test_drives_unique UNIQUE (vin, customer_id, drive_date),
    FOREIGN KEY (vin) REFERENCES vehicles(vin),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

CREATE TABLE service_appointments (
    service_id SERIAL PRIMARY KEY,
    vin CHAR(17) NOT NULL,
    customer_id INT NOT NULL,
    service_date DATE NOT NULL,
    service_type VARCHAR(100) NOT NULL,
    service_notes TEXT NOT NULL DEFAULT '',
    service_notes_tsv tsvector GENERATED ALWAYS AS (to_tsvector(service_notes)) STORED,
    CONSTRAINT service_type_check CHECK (service_type IN ('Tire Rotation','Brake Inspection','Battery Check','Software Update','Annual Service')),
    FOREIGN KEY (vin) REFERENCES vehicles(vin),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    vin CHAR(17) NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT NOT NULL,
    review_date DATE NOT NULL,
    review_tsv tsvector,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (vin) REFERENCES vehicles(vin)
);

-- Expanded design schema
CREATE TABLE lenders (
    lender_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20)
);

CREATE TABLE financing_plans (
    plan_id SERIAL PRIMARY KEY,
    lender_id INT NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    apr NUMERIC(5,2) CHECK (apr > 0),
    term_months INT CHECK (term_months IN (24,36,48,60,72)),
    min_down_payment NUMERIC(10,2) CHECK (min_down_payment >= 0),
    FOREIGN KEY (lender_id) REFERENCES lenders(lender_id)
);

CREATE TABLE loans (
    loan_id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL UNIQUE,
    plan_id INT NOT NULL,
    principal NUMERIC(10,2) CHECK (principal > 0),
    down_payment NUMERIC(10,2) CHECK (down_payment >= 0),
    start_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    CONSTRAINT loans_status_check CHECK (status IN ('Active','Paid','Defaulted')),
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id),
    FOREIGN KEY (plan_id) REFERENCES financing_plans(plan_id)
);

CREATE TABLE trade_ins (
    trade_in_id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL UNIQUE,
    vin CHAR(17),
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    model_year INT CHECK (model_year >= 2000),
    mileage INT CHECK (mileage >= 0),
    allowance NUMERIC(10,2) CHECK (allowance >= 0),
    FOREIGN KEY (sale_id) REFERENCES sales(sale_id)
);

CREATE TABLE inventory_transfers (
    transfer_id SERIAL PRIMARY KEY,
    vin CHAR(17) NOT NULL,
    from_dealership_id INT NOT NULL,
    to_dealership_id INT NOT NULL,
    transfer_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    CONSTRAINT transfer_status_check CHECK (status IN ('Requested','In Transit','Completed','Cancelled')),
    CONSTRAINT transfer_from_to_check CHECK (from_dealership_id <> to_dealership_id),
    FOREIGN KEY (vin) REFERENCES vehicles(vin),
    FOREIGN KEY (from_dealership_id) REFERENCES dealerships(dealership_id),
    FOREIGN KEY (to_dealership_id) REFERENCES dealerships(dealership_id)
);

CREATE TABLE service_invoices (
    invoice_id SERIAL PRIMARY KEY,
    service_id INT NOT NULL UNIQUE,
    total_amount NUMERIC(10,2) CHECK (total_amount >= 0),
    paid BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (service_id) REFERENCES service_appointments(service_id)
);

CREATE TABLE service_items (
    item_id SERIAL PRIMARY KEY,
    invoice_id INT NOT NULL,
    description VARCHAR(100) NOT NULL,
    labor_hours NUMERIC(5,2) CHECK (labor_hours >= 0),
    part_cost NUMERIC(10,2) CHECK (part_cost >= 0),
    labor_rate NUMERIC(10,2) CHECK (labor_rate >= 0),
    FOREIGN KEY (invoice_id) REFERENCES service_invoices(invoice_id)
);

-- Indexes
CREATE INDEX idx_employees_dealership_id ON employees(dealership_id);
CREATE INDEX idx_vehicles_model_id ON vehicles(model_id);
CREATE INDEX idx_vehicles_dealership_id ON vehicles(dealership_id);
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
CREATE INDEX idx_sales_employee_id ON sales(employee_id);
CREATE INDEX idx_sales_vin ON sales(vin);
CREATE INDEX idx_sales_sale_date ON sales(sale_date);
CREATE INDEX idx_payments_sale_id ON payments(sale_id);
CREATE INDEX idx_test_drives_vin ON test_drives(vin);
CREATE INDEX idx_test_drives_customer_id ON test_drives(customer_id);
CREATE INDEX idx_service_appointments_vin ON service_appointments(vin);
CREATE INDEX idx_service_appointments_customer_id ON service_appointments(customer_id);
CREATE INDEX idx_reviews_vin ON reviews(vin);
CREATE INDEX idx_reviews_customer_id ON reviews(customer_id);
CREATE INDEX idx_vehicles_available ON vehicles(available);
CREATE INDEX idx_reviews_review_tsv ON reviews USING GIN (review_tsv);
CREATE INDEX idx_service_notes_tsv ON service_appointments USING GIN (service_notes_tsv);

-- Triggers
CREATE OR REPLACE FUNCTION set_vehicle_unavailable()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE vehicles
  SET available = FALSE
  WHERE vin = NEW.vin;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_vehicle_unavailable_after_sale
AFTER INSERT ON sales
FOR EACH ROW
EXECUTE FUNCTION set_vehicle_unavailable();

CREATE OR REPLACE FUNCTION reviews_tsv_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.review_tsv := to_tsvector(NEW.review_text);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reviews_tsv
BEFORE INSERT OR UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION reviews_tsv_update();

-- Data: base
INSERT INTO customers (full_name, email, phone, join_date) VALUES
('Ava Rodriguez','ava.rodriguez@example.com','212-555-0191','2022-03-15'),
('Liam Chen','liam.chen@example.com','646-555-0182','2021-11-02'),
('Mia Patel','mia.patel@example.com','917-555-0117','2023-01-12'),
('Noah Johnson','noah.johnson@example.com','718-555-0133','2020-08-09'),
('Sophia Kim','sophia.kim@example.com','646-555-0144','2022-06-21'),
('Ethan Wright','ethan.wright@example.com','212-555-0160','2019-05-30'),
('Isabella Garcia','isabella.garcia@example.com','917-555-0175','2023-02-01'),
('Jackson Lee','jackson.lee@example.com','718-555-0109','2021-07-19'),
('Amelia Davis','amelia.davis@example.com','646-555-0128','2022-09-05'),
('Lucas Brown','lucas.brown@example.com','212-555-0156','2020-12-28');

INSERT INTO dealerships (name, city, state) VALUES
('Tesla Downtown Manhattan','New York','NY'),
('Tesla Brooklyn','Brooklyn','NY'),
('Tesla Jersey City','Jersey City','NJ');

INSERT INTO employees (full_name, role, dealership_id) VALUES
('Carlos Nguyen','Sales Manager',1),
('Emma Thompson','Sales Rep',1),
('Olivia Martin','Sales Rep',1),
('Daniel Rivera','Service Advisor',1),
('Sofia Wilson','Technician',1),
('Harper Clark','Sales Manager',2),
('James Allen','Sales Rep',2),
('Charlotte Lopez','Service Advisor',2),
('Benjamin Young','Technician',2),
('Logan Scott','Sales Rep',3);

INSERT INTO models (model_name, base_price, trim_packages) VALUES
('Model 3',39990.00,ARRAY['Standard','Long Range']),
('Model Y',43990.00,ARRAY['Long Range','Performance']),
('Model S',79990.00,ARRAY['Long Range','Plaid']),
('Model X',89990.00,ARRAY['Long Range','Plaid']),
('Cybertruck',60990.00,ARRAY['Dual Motor','Cyberbeast']);

INSERT INTO vehicles (vin, model_id, dealership_id, model_year, color, mileage, price, available, features) VALUES
('5YJ3E1EA7JF000001',1,1,2022,'White',12000,37990.00,TRUE,ARRAY['Autopilot','Heated Seats']),
('5YJ3E1EA7JF000002',1,1,2021,'Black',18000,34990.00,TRUE,ARRAY['Autopilot']),
('5YJYGDEE9MF000003',2,1,2023,'Blue',2500,46990.00,TRUE,ARRAY['Full Self-Driving','Premium Audio']),
('5YJSA1E2XGF000004',3,2,2020,'Red',22000,70990.00,TRUE,ARRAY['Autopilot','Glass Roof']),
('5YJXCDE22HF000005',4,2,2019,'White',30000,68990.00,TRUE,ARRAY['Tow Package']),
('7G2CEHED1RA000006',5,3,2024,'Gray',500,78990.00,TRUE,ARRAY['Off-Road Package','FSD']),
('5YJ3E1EA7JF000007',1,2,2022,'Silver',9000,36990.00,TRUE,ARRAY['Autopilot','Premium Audio']),
('5YJYGDEE9MF000008',2,3,2023,'White',1200,47990.00,TRUE,ARRAY['FSD']),
('5YJSA1E2XGF000009',3,1,2021,'Black',14000,74990.00,TRUE,ARRAY['Autopilot','Cold Weather']),
('5YJXCDE22HF000010',4,3,2020,'Blue',26000,65990.00,TRUE,ARRAY['Tow Package','7-Seat']);

INSERT INTO sales (vin, customer_id, employee_id, sale_date, sale_price) VALUES
('5YJ3E1EA7JF000001',1,2,'2023-05-12',36990.00),
('5YJYGDEE9MF000003',3,1,'2023-06-04',45990.00),
('5YJSA1E2XGF000004',4,6,'2023-04-18',69990.00),
('5YJ3E1EA7JF000007',8,7,'2023-07-02',35990.00),
('5YJXCDE22HF000010',10,10,'2023-03-22',64990.00);

INSERT INTO payments (sale_id, payment_method, amount, payment_date) VALUES
(1,'Financing',30000.00,'2023-05-12'),
(1,'Credit Card',6990.00,'2023-05-12'),
(2,'Bank Transfer',45990.00,'2023-06-05'),
(3,'Financing',50000.00,'2023-04-18'),
(3,'Cash',19990.00,'2023-04-18'),
(4,'Credit Card',5000.00,'2023-07-02'),
(4,'Financing',30990.00,'2023-07-02'),
(5,'Bank Transfer',64990.00,'2023-03-22');

INSERT INTO test_drives (vin, customer_id, employee_id, drive_date) VALUES
('5YJ3E1EA7JF000002',2,2,'2023-05-01'),
('5YJ3E1EA7JF000001',1,3,'2023-04-28'),
('5YJYGDEE9MF000008',5,10,'2023-05-15'),
('5YJSA1E2XGF000009',6,1,'2023-05-20'),
('5YJXCDE22HF000005',7,6,'2023-06-10'),
('5YJ3E1EA7JF000007',8,7,'2023-06-25'),
('5YJYGDEE9MF000003',3,2,'2023-05-28'),
('5YJXCDE22HF000010',10,10,'2023-03-18'),
('7G2CEHED1RA000006',9,10,'2023-07-10'),
('5YJSA1E2XGF000004',4,6,'2023-04-10');

INSERT INTO service_appointments (vin, customer_id, service_date, service_type, service_notes) VALUES
('5YJ3E1EA7JF000001',1,'2023-08-01','Annual Service','Annual service completed; checked battery health and cabin filters.'),
('5YJ3E1EA7JF000001',1,'2023-11-01','Tire Rotation','Tire rotation and alignment check; no issues found.'),
('5YJYGDEE9MF000003',3,'2023-09-15','Software Update','Installed latest software update; recalibrated sensors.'),
('5YJSA1E2XGF000004',4,'2023-07-30','Brake Inspection','Brake inspection and pad wear measurement; within spec.'),
('5YJ3E1EA7JF000007',8,'2023-09-05','Battery Check','Battery diagnostics and cooling system inspection.'),
('5YJXCDE22HF000010',10,'2023-08-20','Annual Service','Annual service with firmware patch and safety checks.'),
('5YJYGDEE9MF000008',5,'2023-10-12','Tire Rotation','Tire rotation; advised customer on pressure settings.'),
('5YJ3E1EA7JF000002',2,'2023-09-01','Software Update','Software update and navigation map refresh.'),
('5YJSA1E2XGF000009',6,'2023-10-25','Brake Inspection','Brake inspection with rotor check; no replacement needed.'),
('5YJXCDE22HF000005',7,'2023-07-05','Battery Check','Battery check and high-voltage system scan.');

INSERT INTO reviews (customer_id, vin, rating, review_text, review_date) VALUES
(1,'5YJ3E1EA7JF000001',5,'Great acceleration and smooth ride. Autopilot is very helpful on long trips.','2023-06-01'),
(3,'5YJYGDEE9MF000003',4,'Spacious interior and quiet cabin. The UI takes some getting used to.','2023-06-20'),
(4,'5YJSA1E2XGF000004',5,'Fantastic performance and premium feel. Charging network is convenient.','2023-05-01'),
(8,'5YJ3E1EA7JF000007',4,'Love the tech features. Ride is a bit firm on rough roads.','2023-07-15'),
(10,'5YJXCDE22HF000010',3,'Plenty of space but wind noise is noticeable at highway speeds.','2023-04-01'),
(2,'5YJ3E1EA7JF000002',4,'Test drive was smooth and quick. Considering purchase soon.','2023-05-02'),
(5,'5YJYGDEE9MF000008',5,'Great efficiency and comfort. Highly recommended.','2023-07-20'),
(6,'5YJSA1E2XGF000009',4,'Performance is excellent and interior is solid.','2023-08-10'),
(7,'5YJXCDE22HF000005',3,'Good towing capability but service wait time was long.','2023-07-12'),
(9,'7G2CEHED1RA000006',5,'Cybertruck is unique and capable. Off-road package is great.','2023-08-05');

-- Data: expanded design
INSERT INTO lenders (name, phone) VALUES
('Bank of Metro','212-555-2001'),
('Hudson Credit Union','201-555-3344'),
('Liberty Auto Finance','646-555-8822');

INSERT INTO financing_plans (lender_id, plan_name, apr, term_months, min_down_payment) VALUES
(1,'Metro Standard 60',5.25,60,2000.00),
(1,'Metro Short 36',4.10,36,3000.00),
(2,'Hudson Flex 72',5.90,72,1500.00),
(3,'Liberty Prime 48',4.75,48,2500.00);

INSERT INTO loans (sale_id, plan_id, principal, down_payment, start_date, status) VALUES
(1,1,30000.00,6990.00,'2023-05-12','Active'),
(3,4,50000.00,19990.00,'2023-04-18','Active'),
(4,2,30990.00,5000.00,'2023-07-02','Active');

INSERT INTO trade_ins (sale_id, vin, make, model, model_year, mileage, allowance) VALUES
(1,'1HGCM82633A000001','Honda','Accord',2016,72000,6500.00),
(3,'5N1AR2MN3FC000002','Nissan','Pathfinder',2015,82000,5800.00),
(4,'2C3CDXBG1GH000003','Dodge','Charger',2017,61000,9000.00);

INSERT INTO inventory_transfers (vin, from_dealership_id, to_dealership_id, transfer_date, status) VALUES
('5YJ3E1EA7JF000002',1,2,'2023-05-05','Completed'),
('5YJYGDEE9MF000008',3,1,'2023-06-01','Completed'),
('5YJSA1E2XGF000009',1,3,'2023-06-15','In Transit');

INSERT INTO service_invoices (service_id, total_amount, paid) VALUES
(1,320.00,TRUE),
(2,85.00,TRUE),
(3,120.00,FALSE),
(4,260.00,TRUE);

INSERT INTO service_items (invoice_id, description, labor_hours, part_cost, labor_rate) VALUES
(1,'Annual inspection',2.0,40.00,120.00),
(1,'Cabin filter',0.5,35.00,120.00),
(2,'Tire rotation',0.7,0.00,120.00),
(3,'Software update',0.5,0.00,120.00),
(4,'Brake inspection',1.5,20.00,120.00);
