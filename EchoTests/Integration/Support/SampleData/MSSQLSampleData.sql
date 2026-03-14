-- Echo Integration Test Sample Data for SQL Server
-- Creates tables, views, procedures, functions, triggers, indexes, and test data.

-- Create test schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'echo_test')
    EXEC('CREATE SCHEMA echo_test');
GO

-- =============================================================================
-- Tables
-- =============================================================================

IF OBJECT_ID('echo_test.employees', 'U') IS NOT NULL DROP TABLE echo_test.employees;
IF OBJECT_ID('echo_test.departments', 'U') IS NOT NULL DROP TABLE echo_test.departments;
IF OBJECT_ID('echo_test.orders', 'U') IS NOT NULL DROP TABLE echo_test.orders;
IF OBJECT_ID('echo_test.order_items', 'U') IS NOT NULL DROP TABLE echo_test.order_items;
IF OBJECT_ID('echo_test.products', 'U') IS NOT NULL DROP TABLE echo_test.products;
IF OBJECT_ID('echo_test.audit_log', 'U') IS NOT NULL DROP TABLE echo_test.audit_log;
GO

CREATE TABLE echo_test.departments (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    code NVARCHAR(10) NOT NULL UNIQUE,
    budget DECIMAL(15,2) DEFAULT 0,
    created_at DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE echo_test.employees (
    id INT IDENTITY(1,1) PRIMARY KEY,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(200) UNIQUE,
    department_id INT REFERENCES echo_test.departments(id),
    salary DECIMAL(10,2),
    hire_date DATE DEFAULT GETDATE(),
    is_active BIT DEFAULT 1,
    metadata NVARCHAR(MAX),
    CONSTRAINT CK_employee_salary CHECK (salary >= 0)
);

CREATE TABLE echo_test.products (
    id INT IDENTITY(1,1) PRIMARY KEY,
    sku NVARCHAR(50) NOT NULL UNIQUE,
    name NVARCHAR(200) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    stock_quantity INT DEFAULT 0,
    category NVARCHAR(50),
    description NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE echo_test.orders (
    id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT REFERENCES echo_test.employees(id),
    order_date DATETIME2 DEFAULT GETDATE(),
    total_amount DECIMAL(15,2) DEFAULT 0,
    status NVARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE echo_test.order_items (
    id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT NOT NULL REFERENCES echo_test.orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES echo_test.products(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL
);

CREATE TABLE echo_test.audit_log (
    id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(128),
    operation NVARCHAR(10),
    old_data NVARCHAR(MAX),
    new_data NVARCHAR(MAX),
    changed_at DATETIME2 DEFAULT GETDATE(),
    changed_by NVARCHAR(128) DEFAULT SYSTEM_USER
);
GO

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX IX_employees_department ON echo_test.employees(department_id);
CREATE INDEX IX_employees_name ON echo_test.employees(last_name, first_name);
CREATE INDEX IX_orders_employee ON echo_test.orders(employee_id);
CREATE INDEX IX_orders_date ON echo_test.orders(order_date DESC);
CREATE INDEX IX_order_items_order ON echo_test.order_items(order_id);
CREATE INDEX IX_products_category ON echo_test.products(category);
GO

-- =============================================================================
-- Views
-- =============================================================================

IF OBJECT_ID('echo_test.v_active_employees', 'V') IS NOT NULL DROP VIEW echo_test.v_active_employees;
GO
CREATE VIEW echo_test.v_active_employees AS
SELECT e.id, e.first_name, e.last_name, e.email, d.name AS department_name, e.salary
FROM echo_test.employees e
LEFT JOIN echo_test.departments d ON e.department_id = d.id
WHERE e.is_active = 1;
GO

IF OBJECT_ID('echo_test.v_order_summary', 'V') IS NOT NULL DROP VIEW echo_test.v_order_summary;
GO
CREATE VIEW echo_test.v_order_summary AS
SELECT o.id AS order_id, e.first_name + ' ' + e.last_name AS employee_name,
       o.order_date, o.total_amount, o.status,
       COUNT(oi.id) AS item_count
FROM echo_test.orders o
LEFT JOIN echo_test.employees e ON o.employee_id = e.id
LEFT JOIN echo_test.order_items oi ON o.id = oi.order_id
GROUP BY o.id, e.first_name, e.last_name, o.order_date, o.total_amount, o.status;
GO

-- =============================================================================
-- Stored Procedures
-- =============================================================================

IF OBJECT_ID('echo_test.usp_get_employees_by_dept', 'P') IS NOT NULL
    DROP PROCEDURE echo_test.usp_get_employees_by_dept;
GO
CREATE PROCEDURE echo_test.usp_get_employees_by_dept
    @department_id INT
AS
BEGIN
    SELECT id, first_name, last_name, email, salary
    FROM echo_test.employees
    WHERE department_id = @department_id AND is_active = 1
    ORDER BY last_name;
END;
GO

IF OBJECT_ID('echo_test.usp_create_order', 'P') IS NOT NULL
    DROP PROCEDURE echo_test.usp_create_order;
GO
CREATE PROCEDURE echo_test.usp_create_order
    @employee_id INT,
    @order_id INT OUTPUT
AS
BEGIN
    INSERT INTO echo_test.orders (employee_id) VALUES (@employee_id);
    SET @order_id = SCOPE_IDENTITY();
END;
GO

-- =============================================================================
-- Functions
-- =============================================================================

IF OBJECT_ID('echo_test.fn_employee_count', 'FN') IS NOT NULL
    DROP FUNCTION echo_test.fn_employee_count;
GO
CREATE FUNCTION echo_test.fn_employee_count(@department_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @count INT;
    SELECT @count = COUNT(*) FROM echo_test.employees
    WHERE department_id = @department_id AND is_active = 1;
    RETURN @count;
END;
GO

IF OBJECT_ID('echo_test.fn_full_name', 'FN') IS NOT NULL
    DROP FUNCTION echo_test.fn_full_name;
GO
CREATE FUNCTION echo_test.fn_full_name(@first NVARCHAR(50), @last NVARCHAR(50))
RETURNS NVARCHAR(101)
AS
BEGIN
    RETURN @first + ' ' + @last;
END;
GO

-- =============================================================================
-- Triggers
-- =============================================================================

IF OBJECT_ID('echo_test.trg_employees_audit', 'TR') IS NOT NULL
    DROP TRIGGER echo_test.trg_employees_audit;
GO
CREATE TRIGGER echo_test.trg_employees_audit
ON echo_test.employees
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        INSERT INTO echo_test.audit_log (table_name, operation)
        VALUES ('employees', 'UPDATE');
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        INSERT INTO echo_test.audit_log (table_name, operation)
        VALUES ('employees', 'INSERT');
    ELSE IF EXISTS (SELECT 1 FROM deleted)
        INSERT INTO echo_test.audit_log (table_name, operation)
        VALUES ('employees', 'DELETE');
END;
GO

-- =============================================================================
-- Sample Data
-- =============================================================================

INSERT INTO echo_test.departments (name, code, budget) VALUES
('Engineering', 'ENG', 500000),
('Sales', 'SLS', 300000),
('Marketing', 'MKT', 200000),
('Human Resources', 'HR', 150000);

INSERT INTO echo_test.employees (first_name, last_name, email, department_id, salary) VALUES
('Alice', 'Johnson', 'alice@example.com', 1, 95000),
('Bob', 'Smith', 'bob@example.com', 1, 88000),
('Carol', 'Williams', 'carol@example.com', 2, 72000),
('David', 'Brown', 'david@example.com', 3, 68000),
('Eve', 'Davis', 'eve@example.com', 4, 75000);

INSERT INTO echo_test.products (sku, name, price, stock_quantity, category) VALUES
('WIDGET-001', 'Standard Widget', 9.99, 100, 'Widgets'),
('WIDGET-002', 'Premium Widget', 19.99, 50, 'Widgets'),
('GADGET-001', 'Basic Gadget', 29.99, 75, 'Gadgets'),
('GADGET-002', 'Pro Gadget', 49.99, 30, 'Gadgets');

INSERT INTO echo_test.orders (employee_id, total_amount, status) VALUES
(1, 29.98, 'completed'),
(2, 49.99, 'pending'),
(3, 79.97, 'shipped');

INSERT INTO echo_test.order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 2, 9.99),
(1, 2, 1, 19.99),
(2, 4, 1, 49.99),
(3, 3, 2, 29.99),
(3, 1, 2, 9.99);
GO
