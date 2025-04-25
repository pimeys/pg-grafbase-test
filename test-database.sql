-- PostgreSQL Schema Example with Tables, Relationships, Enums, Views, Comments, and Test Data

-- Drop existing objects if they exist (optional, for clean setup)
DROP VIEW IF EXISTS order_details_view;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS user_profiles;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS order_status_enum;
DROP TYPE IF EXISTS user_role_enum;

-- =============================================
-- ENUMS
-- =============================================

-- Define an ENUM type for user roles
CREATE TYPE user_role_enum AS ENUM ('customer', 'admin', 'support');
COMMENT ON TYPE user_role_enum IS 'Enumerated type for different roles a user can have.';

-- Define an ENUM type for order statuses
CREATE TYPE order_status_enum AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
COMMENT ON TYPE order_status_enum IS 'Enumerated type for the possible statuses of an order.';


-- =============================================
-- TABLES
-- =============================================

-- Users Table: Stores basic user login information
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY, -- Use SERIAL for auto-incrementing integer PK
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Store hashed passwords, never plain text
    role user_role_enum NOT NULL DEFAULT 'customer',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Record creation time
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP  -- Record last update time
);

-- Add comments for the users table and its columns
COMMENT ON TABLE users IS 'Stores core user account information, including login credentials and role.';
COMMENT ON COLUMN users.user_id IS 'Unique identifier for the user (Primary Key).';
COMMENT ON COLUMN users.email IS 'User''s email address, used for login (must be unique).';
COMMENT ON COLUMN users.password_hash IS 'Hashed representation of the user''s password.';
COMMENT ON COLUMN users.role IS 'Role assigned to the user (e.g., customer, admin). References user_role_enum.';
COMMENT ON COLUMN users.is_active IS 'Flag indicating if the user account is active.';
COMMENT ON COLUMN users.created_at IS 'Timestamp when the user account was created.';
COMMENT ON COLUMN users.updated_at IS 'Timestamp when the user account was last updated.';

-- User Profiles Table: Stores additional user details (1:1 relationship with users)
CREATE TABLE user_profiles (
    profile_id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL, -- Foreign key establishing the 1:1 link
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT, -- For longer text descriptions
    date_of_birth DATE, -- Stores only the date
    profile_picture_url VARCHAR(512), -- URL to a profile picture
    CONSTRAINT fk_user -- Naming the foreign key constraint is good practice
        FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE -- If a user is deleted, delete their profile too
);

-- Add comments for the user_profiles table and its columns
COMMENT ON TABLE user_profiles IS 'Stores supplementary profile information for users. Has a one-to-one relationship with the users table.';
COMMENT ON COLUMN user_profiles.profile_id IS 'Unique identifier for the user profile (Primary Key).';
COMMENT ON COLUMN user_profiles.user_id IS 'Foreign key referencing the associated user in the users table (Unique, enforces 1:1).';
COMMENT ON COLUMN user_profiles.first_name IS 'User''s first name.';
COMMENT ON COLUMN user_profiles.last_name IS 'User''s last name.';
COMMENT ON COLUMN user_profiles.bio IS 'A short biography or description provided by the user.';
COMMENT ON COLUMN user_profiles.date_of_birth IS 'User''s date of birth.';
COMMENT ON COLUMN user_profiles.profile_picture_url IS 'URL pointing to the user''s profile picture.';
COMMENT ON CONSTRAINT fk_user ON user_profiles IS 'Ensures that the user_id in user_profiles refers to a valid user_id in the users table. Deletes profile if user is deleted.';

-- Products Table: Stores information about products available for sale
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0), -- Decimal type for currency, ensure non-negative
    sku VARCHAR(50) UNIQUE, -- Stock Keeping Unit, often unique
    stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0), -- Ensure non-negative stock
    added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add comments for the products table and its columns
COMMENT ON TABLE products IS 'Stores details about the products offered in the store.';
COMMENT ON COLUMN products.product_id IS 'Unique identifier for the product (Primary Key).';
COMMENT ON COLUMN products.name IS 'Name of the product.';
COMMENT ON COLUMN products.description IS 'Detailed description of the product.';
COMMENT ON COLUMN products.price IS 'Price of the product (Numeric with 2 decimal places). Must be non-negative.';
COMMENT ON COLUMN products.sku IS 'Stock Keeping Unit - a unique identifier for inventory management.';
COMMENT ON COLUMN products.stock_quantity IS 'Current quantity of the product in stock. Must be non-negative.';
COMMENT ON COLUMN products.added_at IS 'Timestamp when the product was added to the store.';

-- Orders Table: Stores information about customer orders (1:N relationship with users)
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL, -- Foreign key linking to the user who placed the order
    order_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status order_status_enum NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(12, 2), -- Can be calculated or stored, here stored (might be updated by trigger/app logic)
    shipping_address TEXT,
    billing_address TEXT,
    CONSTRAINT fk_user_order
        FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT -- Prevent deleting a user who has orders (could also use SET NULL or other strategies)
);

-- Add comments for the orders table and its columns
COMMENT ON TABLE orders IS 'Stores information about orders placed by users. Has a one-to-many relationship with the users table.';
COMMENT ON COLUMN orders.order_id IS 'Unique identifier for the order (Primary Key).';
COMMENT ON COLUMN orders.user_id IS 'Foreign key referencing the user who placed the order.';
COMMENT ON COLUMN orders.order_date IS 'Timestamp when the order was placed.';
COMMENT ON COLUMN orders.status IS 'Current status of the order (e.g., pending, shipped). References order_status_enum.';
COMMENT ON COLUMN orders.total_amount IS 'The total calculated amount for the order.';
COMMENT ON COLUMN orders.shipping_address IS 'The address where the order should be shipped.';
COMMENT ON COLUMN orders.billing_address IS 'The address associated with the payment method.';
COMMENT ON CONSTRAINT fk_user_order ON orders IS 'Ensures that the user_id in orders refers to a valid user_id in the users table. Prevents user deletion if they have orders.';

-- Order Items Table: Junction table for the N:M relationship between Orders and Products
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0), -- Must order at least one item
    price_at_purchase NUMERIC(10, 2) NOT NULL, -- Store the price at the time of purchase, as product price might change
    CONSTRAINT fk_order
        FOREIGN KEY(order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE, -- If an order is deleted, remove its items
    CONSTRAINT fk_product
        FOREIGN KEY(product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT, -- Prevent deleting a product if it's part of an order
    UNIQUE (order_id, product_id) -- Ensure a product appears only once per order
);

-- Add comments for the order_items table and its columns
COMMENT ON TABLE order_items IS 'Acts as a junction table to link orders and products, representing the items included in each order. Establishes a many-to-many relationship between orders and products.';
COMMENT ON COLUMN order_items.order_item_id IS 'Unique identifier for the specific item within an order (Primary Key).';
COMMENT ON COLUMN order_items.order_id IS 'Foreign key referencing the order this item belongs to.';
COMMENT ON COLUMN order_items.product_id IS 'Foreign key referencing the product included in this order item.';
COMMENT ON COLUMN order_items.quantity IS 'The number of units of the product ordered. Must be greater than zero.';
COMMENT ON COLUMN order_items.price_at_purchase IS 'The price of the product per unit at the time the order was placed.';
COMMENT ON CONSTRAINT fk_order ON order_items IS 'Ensures order_id references a valid order. Deletes item if order is deleted.';
COMMENT ON CONSTRAINT fk_product ON order_items IS 'Ensures product_id references a valid product. Prevents product deletion if it exists in any order item.';
COMMENT ON CONSTRAINT order_items_order_id_product_id_key ON order_items IS 'Ensures that a specific product can only appear once within the same order.';


-- =============================================
-- INDEXES (Optional but good for performance)
-- =============================================

-- Index on foreign keys and frequently queried columns
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

COMMENT ON INDEX idx_users_email IS 'Index to speed up lookups based on user email.';
COMMENT ON INDEX idx_products_name IS 'Index to speed up searches for products by name.';
COMMENT ON INDEX idx_orders_user_id IS 'Index to quickly find all orders for a specific user.';


-- =============================================
-- VIEWS
-- =============================================

-- View to get detailed information about orders and the items within them
CREATE VIEW order_details_view AS
SELECT
    o.order_id,
    o.order_date,
    o.status AS order_status,
    u.user_id,
    u.email AS user_email,
    up.first_name,
    up.last_name,
    oi.order_item_id,
    p.product_id,
    p.name AS product_name,
    oi.quantity,
    oi.price_at_purchase,
    (oi.quantity * oi.price_at_purchase) AS item_total_price
FROM
    orders o
JOIN
    users u ON o.user_id = u.user_id
LEFT JOIN -- Use LEFT JOIN for profile in case a profile doesn't exist (though our 1:1 FK prevents this unless user_id is NULL)
    user_profiles up ON u.user_id = up.user_id
JOIN
    order_items oi ON o.order_id = oi.order_id
JOIN
    products p ON oi.product_id = p.product_id
ORDER BY
    o.order_id, oi.order_item_id;

-- Add comments for the view and its columns
COMMENT ON VIEW order_details_view IS 'Provides a consolidated view of orders, including user details, product information for each item, quantity, and price.';
COMMENT ON COLUMN order_details_view.order_id IS 'Identifier of the order.';
COMMENT ON COLUMN order_details_view.order_date IS 'Date the order was placed.';
COMMENT ON COLUMN order_details_view.order_status IS 'Current status of the order.';
COMMENT ON COLUMN order_details_view.user_id IS 'Identifier of the user who placed the order.';
COMMENT ON COLUMN order_details_view.user_email IS 'Email of the user who placed the order.';
COMMENT ON COLUMN order_details_view.first_name IS 'First name of the user.';
COMMENT ON COLUMN order_details_view.last_name IS 'Last name of the user.';
COMMENT ON COLUMN order_details_view.order_item_id IS 'Identifier of the specific item within the order.';
COMMENT ON COLUMN order_details_view.product_id IS 'Identifier of the product ordered.';
COMMENT ON COLUMN order_details_view.product_name IS 'Name of the product ordered.';
COMMENT ON COLUMN order_details_view.quantity IS 'Quantity of the product ordered.';
COMMENT ON COLUMN order_details_view.price_at_purchase IS 'Price per unit of the product at the time of purchase.';
COMMENT ON COLUMN order_details_view.item_total_price IS 'Calculated total price for this specific order item (quantity * price_at_purchase).';


-- =============================================
-- TEST DATA
-- =============================================

-- Insert Users
INSERT INTO users (email, password_hash, role, is_active) VALUES
('alice@example.com', 'hash123', 'customer', TRUE),
('bob@example.com', 'hash456', 'customer', TRUE),
('charlie@example.com', 'hash789', 'admin', TRUE),
('diana@example.com', 'hash000', 'customer', FALSE); -- Inactive user

-- Insert User Profiles (matching user_ids)
INSERT INTO user_profiles (user_id, first_name, last_name, bio, date_of_birth) VALUES
(1, 'Alice', 'Smith', 'Loves hiking and coding.', '1990-05-15'),
(2, 'Bob', 'Johnson', NULL, '1985-11-22'), -- No bio
(3, 'Charlie', 'Davis', 'System Administrator', '1992-02-10');
-- No profile for Diana (user_id 4) to show LEFT JOIN behavior in view (though FK prevents this if NOT NULL)

-- Insert Products
INSERT INTO products (name, description, price, sku, stock_quantity) VALUES
('Laptop Pro', 'High-performance laptop for professionals.', 1200.00, 'LP1001', 50),
('Wireless Mouse', 'Ergonomic wireless mouse.', 25.50, 'WM2002', 150),
('Mechanical Keyboard', 'RGB Mechanical Keyboard with blue switches.', 75.00, 'MK3003', 75),
('USB-C Hub', '7-in-1 USB-C Hub with HDMI and SD card reader.', 40.00, 'UCH4004', 200),
('Webcam HD', '1080p HD Webcam with built-in microphone.', 55.99, 'WC5005', 0); -- Out of stock

-- Insert Orders (link to users)
-- Note: total_amount might be calculated by application logic or triggers later
INSERT INTO orders (user_id, status, shipping_address, billing_address, total_amount) VALUES
(1, 'shipped', '123 Main St, Anytown, USA', '123 Main St, Anytown, USA', 1225.50), -- Alice's order
(2, 'pending', '456 Oak Ave, Somewhere, USA', '456 Oak Ave, Somewhere, USA', 115.00), -- Bob's order
(1, 'delivered', '123 Main St, Anytown, USA', 'P.O. Box 100, Anytown', 40.00); -- Alice's second order

-- Insert Order Items (link orders and products)
-- Order 1 (Alice)
INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES
(1, 1, 1, 1200.00), -- 1 Laptop Pro
(1, 2, 1, 25.50);   -- 1 Wireless Mouse

-- Order 2 (Bob)
INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES
(2, 3, 1, 75.00),  -- 1 Mechanical Keyboard
(2, 4, 1, 40.00);  -- 1 USB-C Hub

-- Order 3 (Alice)
INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES
(3, 4, 1, 40.00);  -- 1 USB-C Hub (again, different order)

-- =============================================
-- Example Queries
-- =============================================

-- Select all active users
-- SELECT * FROM users WHERE is_active = TRUE;

-- Select all products with stock > 0
-- SELECT name, price, stock_quantity FROM products WHERE stock_quantity > 0 ORDER BY name;

-- Select details for a specific order using the view
-- SELECT * FROM order_details_view WHERE order_id = 1;

-- Select all orders placed by Alice
-- SELECT o.order_id, o.order_date, o.status
-- FROM orders o
-- JOIN users u ON o.user_id = u.user_id
-- WHERE u.email = 'alice@example.com';


