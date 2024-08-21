```
-- global changes
CREATE USER cdc_user WITH ENCRYPTED PASSWORD '<password>';
GRANT rds_superuser TO cdc_user;

-- schema specific changes
GRANT ALL ON SCHEMA public TO cdc_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO cdc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO cdc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO cdc_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO cdc_user;

-- database specific change
CREATE PUBLICATION alltables FOR ALL TABLES;

-- database specific changes
CREATE TABLE onehouse_heartbeat (
    id INTEGER DEFAULT 1 PRIMARY KEY, 
    updated_at timestamp
    );

INSERT INTO onehouse_heartbeat DEFAULT VALUES ON CONFLICT (id) DO UPDATE SET updated_at=NOW();

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    title TEXT,
    price INTEGER
);
INSERT INTO books(book_id, title, price)
VALUES
    ('101', 'Jobs', '2000'),
    ('102', 'Geeta', '250'),
    ('103', 'Ramayana', '354'),
    ('104', 'Vedas', '268');
    
INSERT INTO books(book_id, title, price)
VALUES
    ('105', 'Albert', '2000'),
    ('106', 'George', '250'),
    ('107', 'Ray', '354'),
    ('108', 'Bob', '268');   

CREATE TABLE toys (
    toy_id INTEGER PRIMARY KEY,
    name TEXT,
    price INTEGER
);
INSERT INTO toys(toy_id, name, price)
VALUES
    ('101', 'Jobs', '2000'),
    ('102', 'Geeta', '250'),
    ('103', 'Ramayana', '354'),
    ('104', 'Vedas', '268');   
  INSERT INTO toys(toy_id, name, price)
VALUES
    ('202', 'Jobs', '2000');
   
     INSERT INTO toys(toy_id, name, price)
VALUES
    ('203', 'Jobs', '2000');
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    name TEXT,
    city TEXT,
    email TEXT,
    created_at TEXT,
    address TEXT,
    state TEXT
);

INSERT INTO customers (customer_id, name, city, email, created_at,address,state)
VALUES
    ('1', 'John Doe', 'New York', 'john@example.com', '2022-01-01', '123 Main St', 'NY'),
    ('2', 'Jane Smith', 'Los Angeles', 'jane@example.com', '2022-01-02', '456 Elm St', 'CA'),
    ('3', 'Alice Johnson', 'Chicago', 'alice@example.com', '2022-01-03', '789 Oak St', 'IL');

INSERT INTO customers (customer_id, name, city, email, created_at,address,state)
VALUES
    ('4', 'John Doe', 'New York', 'john@example.com', '2022-01-01', '123 Main St', 'NY');

INSERT INTO customers (customer_id, name, city, email, created_at,address,state)
VALUES
    ('5', 'John Doe2', 'New York2', 'john@example.com2', '2022-01-02', '765 Main St', 'NY');   
INSERT INTO customers (customer_id, name, city, email, created_at,address,state)
VALUES
    ('6', 'John Doe2', 'New York2', 'john@example.com2', '2022-01-02', '765 Main St', 'NY');      
   INSERT INTO customers (customer_id, name, city, email, created_at,address,state)
VALUES
    ('7', 'John Doe', 'New York2', 'john@example.com2', '2022-01-02', '765 Main St', 'NY');   
CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT,
    product_id TEXT,
    quantity TEXT,
    total_price TEXT,
    order_date TEXT
);

INSERT INTO orders
VALUES
    ('101', '1', 'P123', '2', '45.99', '2022-01-02'),
    ('102', '1', 'P456', '1', '29.99', '2022-01-03'),
    ('103', '2', 'P789', '3', '99.99', '2022-01-01'),
    ('104', '3', 'P123', '1', '49.99', '2022-01-02');
   
INSERT INTO orders
VALUES
    ('201', '3', 'P123', '1', '49.99', '2022-01-02');
   


CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    name TEXT,
    city TEXT,
    email TEXT,
    created_at TEXT,
    address TEXT,
    state TEXT
);

INSERT INTO users (user_id, name, city, email, created_at,address,state)
VALUES
    ('1', 'John Doe', 'New York', 'john@example.com', '2022-01-01', '123 Main St', 'NY'),
    ('2', 'Jane Smith', 'Los Angeles', 'jane@example.com', '2022-01-02', '456 Elm St', 'CA'),
    ('3', 'Alice Johnson', 'Chicago', 'alice@example.com', '2022-01-03', '789 Oak St', 'IL');
   
INSERT INTO users (user_id, name, city, email, created_at,address,state)
VALUES
    ('4', 'Albert Wong', 'New York', 'john@example.com', '2022-01-01', '123 Main St', 'NY');
   
INSERT INTO users (user_id, name, city, email, created_at,address,state)
VALUES
    ('5', 'Juan Montenegro', 'New York', 'john@example.com', '2022-01-01', '123 Main St', 'NY');
   
```
