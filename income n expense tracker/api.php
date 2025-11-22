<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

// Database configuration
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '@Shree1887');
define('DB_NAME', 'finance_tracker');

// Create database connection
function getConnection() {
    try {
        $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
        
        if ($conn->connect_error) {
            throw new Exception("Connection failed: " . $conn->connect_error);
        }
        
        $conn->set_charset("utf8mb4");
        return $conn;
    } catch (Exception $e) {
        die(json_encode([
            'success' => false,
            'message' => $e->getMessage()
        ]));
    }
}

// Handle GET requests
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $action = $_GET['action'] ?? '';
    
    switch ($action) {
        case 'getAll':
            getAllTransactions();
            break;
        case 'get':
            getTransaction($_GET['id'] ?? 0);
            break;
        case 'stats':
            getStatistics();
            break;
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
}

// Handle POST requests
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $action = $input['action'] ?? '';
    
    switch ($action) {
        case 'add':
            addTransaction($input);
            break;
        case 'update':
            updateTransaction($input);
            break;
        case 'delete':
            deleteTransaction($input['id'] ?? 0);
            break;
        default:
            echo json_encode(['success' => false, 'message' => 'Invalid action']);
    }
}

// Get all transactions
function getAllTransactions() {
    $conn = getConnection();
    
    $sql = "SELECT * FROM transactions ORDER BY date DESC, created_at DESC";
    $result = $conn->query($sql);
    
    $transactions = [];
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $transactions[] = $row;
        }
    }
    
    $conn->close();
    
    echo json_encode([
        'success' => true,
        'data' => $transactions
    ]);
}

// Get single transaction
function getTransaction($id) {
    $conn = getConnection();
    
    $stmt = $conn->prepare("SELECT * FROM transactions WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $transaction = $result->fetch_assoc();
        echo json_encode([
            'success' => true,
            'data' => $transaction
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Transaction not found'
        ]);
    }
    
    $stmt->close();
    $conn->close();
}

// Add new transaction
function addTransaction($data) {
    $conn = getConnection();
    
    $type = $data['type'] ?? '';
    $category = $data['category'] ?? '';
    $amount = $data['amount'] ?? 0;
    $description = $data['description'] ?? '';
    $date = $data['date'] ?? date('Y-m-d');
    
    // Validate required fields
    if (empty($type) || empty($category) || $amount <= 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Please fill all required fields'
        ]);
        $conn->close();
        return;
    }
    
    $stmt = $conn->prepare("INSERT INTO transactions (type, category, amount, description, date) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("ssdss", $type, $category, $amount, $description, $date);
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Transaction added successfully',
            'id' => $stmt->insert_id
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Error adding transaction: ' . $stmt->error
        ]);
    }
    
    $stmt->close();
    $conn->close();
}

// Update transaction
function updateTransaction($data) {
    $conn = getConnection();
    
    $id = $data['id'] ?? 0;
    $type = $data['type'] ?? '';
    $category = $data['category'] ?? '';
    $amount = $data['amount'] ?? 0;
    $description = $data['description'] ?? '';
    $date = $data['date'] ?? date('Y-m-d');
    
    if ($id <= 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid transaction ID'
        ]);
        $conn->close();
        return;
    }
    
    $stmt = $conn->prepare("UPDATE transactions SET type = ?, category = ?, amount = ?, description = ?, date = ? WHERE id = ?");
    $stmt->bind_param("ssdssi", $type, $category, $amount, $description, $date, $id);
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Transaction updated successfully'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Error updating transaction: ' . $stmt->error
        ]);
    }
    
    $stmt->close();
    $conn->close();
}

// Delete transaction
function deleteTransaction($id) {
    $conn = getConnection();
    
    if ($id <= 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid transaction ID'
        ]);
        $conn->close();
        return;
    }
    
    $stmt = $conn->prepare("DELETE FROM transactions WHERE id = ?");
    $stmt->bind_param("i", $id);
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Transaction deleted successfully'
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Error deleting transaction: ' . $stmt->error
        ]);
    }
    
    $stmt->close();
    $conn->close();
}

// Get statistics
function getStatistics() {
    $conn = getConnection();
    
    // Get total income
    $incomeResult = $conn->query("SELECT SUM(amount) as total FROM transactions WHERE type = 'income'");
    $totalIncome = $incomeResult->fetch_assoc()['total'] ?? 0;
    
    // Get total expenses
    $expenseResult = $conn->query("SELECT SUM(amount) as total FROM transactions WHERE type = 'expense'");
    $totalExpense = $expenseResult->fetch_assoc()['total'] ?? 0;
    
    // Get category breakdown
    $categoryResult = $conn->query("SELECT category, type, SUM(amount) as total FROM transactions GROUP BY category, type");
    $categories = [];
    while ($row = $categoryResult->fetch_assoc()) {
        $categories[] = $row;
    }
    
    // Get monthly data
    $monthlyResult = $conn->query("
        SELECT 
            DATE_FORMAT(date, '%Y-%m') as month,
            type,
            SUM(amount) as total
        FROM transactions
        GROUP BY DATE_FORMAT(date, '%Y-%m'), type
        ORDER BY month DESC
        LIMIT 12
    ");
    $monthly = [];
    while ($row = $monthlyResult->fetch_assoc()) {
        $monthly[] = $row;
    }
    
    $conn->close();
    
    echo json_encode([
        'success' => true,
        'data' => [
            'totalIncome' => $totalIncome,
            'totalExpense' => $totalExpense,
            'balance' => $totalIncome - $totalExpense,
            'categories' => $categories,
            'monthly' => $monthly
        ]
    ]);
}
?>