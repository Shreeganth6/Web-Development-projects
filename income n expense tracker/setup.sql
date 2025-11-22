-- Create database
CREATE DATABASE IF NOT EXISTS finance_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE finance_tracker;

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('income', 'expense') NOT NULL,
    category VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_type (type),
    INDEX idx_date (date),
    INDEX idx_category (category),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create users table (for future account management)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    INDEX idx_email (email),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create categories table (for customizable categories)
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type ENUM('income', 'expense', 'both') NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(7),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_name_type (name, type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create budgets table (for budget tracking)
CREATE TABLE IF NOT EXISTS budgets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    period ENUM('weekly', 'monthly', 'yearly') DEFAULT 'monthly',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_period (period)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create recurring_transactions table (for recurring transactions)
CREATE TABLE IF NOT EXISTS recurring_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    type ENUM('income', 'expense') NOT NULL,
    category VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    frequency ENUM('daily', 'weekly', 'monthly', 'yearly') NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    next_occurrence DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_next_occurrence (next_occurrence),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data for testing
INSERT INTO transactions (type, category, amount, description, date) VALUES
('income', 'Salary', 50000.00, 'Monthly salary', '2024-11-01'),
('expense', 'Food', 2500.00, 'Grocery shopping', '2024-11-03'),
('expense', 'Transport', 1200.00, 'Monthly metro pass', '2024-11-05'),
('income', 'Freelance', 15000.00, 'Web design project', '2024-11-07'),
('expense', 'Bills', 3500.00, 'Electricity and water bill', '2024-11-10'),
('expense', 'Entertainment', 1800.00, 'Movie tickets and dinner', '2024-11-12'),
('expense', 'Shopping', 5000.00, 'New clothes', '2024-11-15'),
('income', 'Investment', 8000.00, 'Stock dividend', '2024-11-18'),
('expense', 'Healthcare', 2000.00, 'Medical checkup', '2024-11-20'),
('expense', 'Food', 3200.00, 'Restaurant expenses', '2024-11-22');

-- Insert default categories
INSERT INTO categories (name, type, icon, color) VALUES
('Salary', 'income', 'fa-briefcase', '#667eea'),
('Freelance', 'income', 'fa-laptop', '#764ba2'),
('Investment', 'income', 'fa-chart-line', '#4facfe'),
('Business', 'income', 'fa-building', '#43e97b'),
('Food', 'expense', 'fa-utensils', '#f5576c'),
('Transport', 'expense', 'fa-car', '#f093fb'),
('Shopping', 'expense', 'fa-shopping-bag', '#fa709a'),
('Bills', 'expense', 'fa-file-invoice', '#fee140'),
('Entertainment', 'expense', 'fa-film', '#30cfd0'),
('Healthcare', 'expense', 'fa-heart-pulse', '#ff6b6b'),
('Education', 'expense', 'fa-graduation-cap', '#4ecdc4'),
('Other', 'both', 'fa-ellipsis', '#95a5a6');

-- Create view for monthly summary
CREATE OR REPLACE VIEW monthly_summary AS
SELECT 
    DATE_FORMAT(date, '%Y-%m') as month,
    SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
    SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expense,
    SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END) as net_balance,
    COUNT(*) as transaction_count
FROM transactions
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month DESC;

-- Create view for category summary
CREATE OR REPLACE VIEW category_summary AS
SELECT 
    category,
    type,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    MIN(amount) as min_amount,
    MAX(amount) as max_amount
FROM transactions
GROUP BY category, type
ORDER BY total_amount DESC;

-- Create stored procedure for getting date range transactions
DELIMITER //

CREATE PROCEDURE GetTransactionsByDateRange(
    IN start_date DATE,
    IN end_date DATE
)
BEGIN
    SELECT * FROM transactions
    WHERE date BETWEEN start_date AND end_date
    ORDER BY date DESC;
END //

-- Create stored procedure for monthly report
CREATE PROCEDURE GetMonthlyReport(
    IN report_month VARCHAR(7)  -- Format: YYYY-MM
)
BEGIN
    SELECT 
        type,
        category,
        COUNT(*) as count,
        SUM(amount) as total,
        AVG(amount) as average
    FROM transactions
    WHERE DATE_FORMAT(date, '%Y-%m') = report_month
    GROUP BY type, category
    ORDER BY total DESC;
END //

-- Create stored procedure for budget vs actual comparison
CREATE PROCEDURE CompareBudgetVsActual(
    IN check_month VARCHAR(7)
)
BEGIN
    SELECT 
        b.category,
        b.amount as budget_amount,
        COALESCE(SUM(t.amount), 0) as actual_amount,
        (b.amount - COALESCE(SUM(t.amount), 0)) as difference,
        ROUND((COALESCE(SUM(t.amount), 0) / b.amount * 100), 2) as percentage_used
    FROM budgets b
    LEFT JOIN transactions t ON b.category = t.category 
        AND t.type = 'expense'
        AND DATE_FORMAT(t.date, '%Y-%m') = check_month
    WHERE b.period = 'monthly'
        AND DATE_FORMAT(b.start_date, '%Y-%m') <= check_month
        AND (b.end_date IS NULL OR DATE_FORMAT(b.end_date, '%Y-%m') >= check_month)
    GROUP BY b.id, b.category, b.amount
    ORDER BY percentage_used DESC;
END //

DELIMITER ;

-- Create trigger to update updated_at timestamp
DELIMITER //

CREATE TRIGGER before_transaction_update
BEFORE UPDATE ON transactions
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //

DELIMITER ;

-- Grant privileges (adjust as needed for your setup)
-- GRANT ALL PRIVILEGES ON finance_tracker.* TO 'your_username'@'localhost';
-- FLUSH PRIVILEGES;