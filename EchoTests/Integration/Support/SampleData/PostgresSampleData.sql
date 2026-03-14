-- Echo Integration Test Sample Data for PostgreSQL
-- Creates schemas, tables, views, functions, triggers, indexes, and test data.

-- =============================================================================
-- Schemas
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS echo_test;

-- =============================================================================
-- Extensions (safe to run multiple times)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "hstore";

-- =============================================================================
-- Custom Types
-- =============================================================================

DO $$ BEGIN
    CREATE TYPE echo_test.order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =============================================================================
-- Tables
-- =============================================================================

DROP TABLE IF EXISTS echo_test.order_items CASCADE;
DROP TABLE IF EXISTS echo_test.orders CASCADE;
DROP TABLE IF EXISTS echo_test.employees CASCADE;
DROP TABLE IF EXISTS echo_test.departments CASCADE;
DROP TABLE IF EXISTS echo_test.products CASCADE;
DROP TABLE IF EXISTS echo_test.audit_log CASCADE;
DROP TABLE IF EXISTS echo_test.tags CASCADE;

CREATE TABLE echo_test.departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    budget NUMERIC(15,2) DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    settings HSTORE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE echo_test.employees (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(200) UNIQUE,
    department_id INTEGER REFERENCES echo_test.departments(id) ON DELETE SET NULL,
    salary NUMERIC(10,2),
    hire_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT TRUE,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB,
    search_vector TSVECTOR,
    CONSTRAINT ck_employee_salary CHECK (salary >= 0)
);

CREATE TABLE echo_test.products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock_quantity INTEGER DEFAULT 0,
    category VARCHAR(50),
    description TEXT,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE echo_test.orders (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES echo_test.employees(id),
    order_date TIMESTAMPTZ DEFAULT NOW(),
    total_amount NUMERIC(15,2) DEFAULT 0,
    status echo_test.order_status DEFAULT 'pending'
);

CREATE TABLE echo_test.order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES echo_test.orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES echo_test.products(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL
);

CREATE TABLE echo_test.audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(128),
    operation VARCHAR(10),
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    changed_by VARCHAR(128) DEFAULT CURRENT_USER
);

CREATE TABLE echo_test.tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    usage_count INTEGER DEFAULT 0
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_employees_department ON echo_test.employees(department_id);
CREATE INDEX IF NOT EXISTS ix_employees_name ON echo_test.employees(last_name, first_name);
CREATE INDEX IF NOT EXISTS ix_employees_search ON echo_test.employees USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS ix_employees_tags ON echo_test.employees USING GIN(tags);
CREATE INDEX IF NOT EXISTS ix_orders_employee ON echo_test.orders(employee_id);
CREATE INDEX IF NOT EXISTS ix_orders_date ON echo_test.orders(order_date DESC);
CREATE INDEX IF NOT EXISTS ix_order_items_order ON echo_test.order_items(order_id);
CREATE INDEX IF NOT EXISTS ix_products_category ON echo_test.products(category);
CREATE INDEX IF NOT EXISTS ix_products_properties ON echo_test.products USING GIN(properties);
CREATE INDEX IF NOT EXISTS ix_departments_metadata ON echo_test.departments USING GIN(metadata);

-- Partial index
CREATE INDEX IF NOT EXISTS ix_employees_active ON echo_test.employees(department_id)
    WHERE is_active = TRUE;

-- =============================================================================
-- Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION echo_test.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION echo_test.update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = to_tsvector('english', COALESCE(NEW.first_name, '') || ' ' || COALESCE(NEW.last_name, '') || ' ' || COALESCE(NEW.email, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION echo_test.log_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO echo_test.audit_log (table_name, operation, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO echo_test.audit_log (table_name, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO echo_test.audit_log (table_name, operation, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD)::JSONB);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION echo_test.employee_count(dept_id INTEGER)
RETURNS INTEGER AS $$
    SELECT COUNT(*)::INTEGER FROM echo_test.employees
    WHERE department_id = dept_id AND is_active = TRUE;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION echo_test.full_name(first VARCHAR, last VARCHAR)
RETURNS VARCHAR AS $$
    SELECT first || ' ' || last;
$$ LANGUAGE sql IMMUTABLE;

-- =============================================================================
-- Triggers
-- =============================================================================

DROP TRIGGER IF EXISTS trg_employees_search ON echo_test.employees;
CREATE TRIGGER trg_employees_search
    BEFORE INSERT OR UPDATE ON echo_test.employees
    FOR EACH ROW EXECUTE FUNCTION echo_test.update_search_vector();

DROP TRIGGER IF EXISTS trg_employees_audit ON echo_test.employees;
CREATE TRIGGER trg_employees_audit
    AFTER INSERT OR UPDATE OR DELETE ON echo_test.employees
    FOR EACH ROW EXECUTE FUNCTION echo_test.log_change();

-- =============================================================================
-- Views
-- =============================================================================

CREATE OR REPLACE VIEW echo_test.v_active_employees AS
SELECT e.id, e.first_name, e.last_name, e.email, d.name AS department_name, e.salary
FROM echo_test.employees e
LEFT JOIN echo_test.departments d ON e.department_id = d.id
WHERE e.is_active = TRUE;

CREATE OR REPLACE VIEW echo_test.v_order_summary AS
SELECT o.id AS order_id,
       e.first_name || ' ' || e.last_name AS employee_name,
       o.order_date, o.total_amount, o.status::TEXT,
       COUNT(oi.id) AS item_count
FROM echo_test.orders o
LEFT JOIN echo_test.employees e ON o.employee_id = e.id
LEFT JOIN echo_test.order_items oi ON o.id = oi.order_id
GROUP BY o.id, e.first_name, e.last_name, o.order_date, o.total_amount, o.status;

-- Materialized view
DROP MATERIALIZED VIEW IF EXISTS echo_test.mv_department_stats;
CREATE MATERIALIZED VIEW echo_test.mv_department_stats AS
SELECT d.id, d.name, COUNT(e.id) AS employee_count, AVG(e.salary) AS avg_salary
FROM echo_test.departments d
LEFT JOIN echo_test.employees e ON d.id = e.department_id AND e.is_active = TRUE
GROUP BY d.id, d.name;

-- =============================================================================
-- Sequences
-- =============================================================================

DROP SEQUENCE IF EXISTS echo_test.invoice_seq;
CREATE SEQUENCE echo_test.invoice_seq START 1000 INCREMENT 1;

DROP SEQUENCE IF EXISTS echo_test.ticket_seq;
CREATE SEQUENCE echo_test.ticket_seq START 1 INCREMENT 10;

-- =============================================================================
-- Sample Data
-- =============================================================================

INSERT INTO echo_test.departments (name, code, budget, metadata, settings) VALUES
('Engineering', 'ENG', 500000, '{"floor": 3, "headcount_limit": 50}', 'manager => "Alice", location => "Building A"'),
('Sales', 'SLS', 300000, '{"floor": 2, "headcount_limit": 30}', 'manager => "Carol", location => "Building B"'),
('Marketing', 'MKT', 200000, '{"floor": 2, "headcount_limit": 20}', NULL),
('Human Resources', 'HR', 150000, '{"floor": 1, "headcount_limit": 10}', NULL);

INSERT INTO echo_test.employees (first_name, last_name, email, department_id, salary, tags) VALUES
('Alice', 'Johnson', 'alice@example.com', 1, 95000, ARRAY['lead', 'senior']),
('Bob', 'Smith', 'bob@example.com', 1, 88000, ARRAY['senior']),
('Carol', 'Williams', 'carol@example.com', 2, 72000, ARRAY['manager']),
('David', 'Brown', 'david@example.com', 3, 68000, ARRAY['junior']),
('Eve', 'Davis', 'eve@example.com', 4, 75000, ARRAY['manager', 'senior']);

INSERT INTO echo_test.products (sku, name, price, stock_quantity, category, properties) VALUES
('WIDGET-001', 'Standard Widget', 9.99, 100, 'Widgets', '{"color": "blue", "weight": 0.5}'),
('WIDGET-002', 'Premium Widget', 19.99, 50, 'Widgets', '{"color": "gold", "weight": 0.8}'),
('GADGET-001', 'Basic Gadget', 29.99, 75, 'Gadgets', '{"color": "black", "weight": 1.2}'),
('GADGET-002', 'Pro Gadget', 49.99, 30, 'Gadgets', '{"color": "silver", "weight": 1.5}');

INSERT INTO echo_test.orders (employee_id, total_amount, status) VALUES
(1, 29.98, 'delivered'),
(2, 49.99, 'pending'),
(3, 79.97, 'shipped');

INSERT INTO echo_test.order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 2, 9.99),
(1, 2, 1, 19.99),
(2, 4, 1, 49.99),
(3, 3, 2, 29.99),
(3, 1, 2, 9.99);

-- Refresh materialized view with data
REFRESH MATERIALIZED VIEW echo_test.mv_department_stats;
