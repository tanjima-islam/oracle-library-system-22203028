-- 1. Create Indexes on Frequently Queried Columns
-- These indexes help speed up queries that filter or sort by author, title, member_id, and book_id.
CREATE INDEX idx_books_author ON BOOKS(author);
CREATE INDEX idx_books_title ON BOOKS(title);
CREATE INDEX idx_transactions_member ON TRANSACTIONS(member_id);
CREATE INDEX idx_transactions_book ON TRANSACTIONS(book_id);

-- 2. Query to Show Execution Plan for Finding Books by Author and Title
-- This query will display the execution plan for retrieving books written by 'Jane Doe'
-- and having 'Mystery' in their title. The EXPLAIN statement helps understand
-- how the database will execute the query, including which indexes it might use.
EXPLAIN SELECT * FROM BOOKS WHERE author = 'Jane Doe' AND title LIKE '%Mystery%';


-- 4. Display member borrowing trends with LAG function to show previous transaction date
-- This query uses the LAG window function to show the issue_date of the previous transaction
-- for each member, ordered by their transaction history.
SELECT
    member_id,
    transaction_id,
    issue_date,
    LAG(issue_date) OVER (PARTITION BY member_id ORDER BY issue_date) AS previous_transaction_date
FROM TRANSACTIONS
ORDER BY member_id, issue_date;


-- Task 4.1: Stored Procedure to Issue a Book
-- This stored procedure handles the logic for issuing a book to a member.
-- It checks for book availability, generates a new transaction ID,
-- inserts a transaction record, and updates the available copies of the book.
-- It also includes transaction management (START TRANSACTION, COMMIT, ROLLBACK)
-- and error handling.
DELIMITER $$

CREATE PROCEDURE ISSUE_BOOK (
    IN p_member_id INT,
    IN p_book_id INT
)
proc_label: BEGIN
    DECLARE v_available INT DEFAULT 0;
    DECLARE v_max_transaction_id INT DEFAULT 0;

    -- Error handler for any SQL exceptions during the transaction
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; -- Rollback the transaction on error
        SELECT 'Error: Could not issue book.' AS message;
    END;

    START TRANSACTION; -- Begin a new transaction

    -- Check book availability and lock the row for update to prevent race conditions
    SELECT available_copies INTO v_available
    FROM BOOKS
    WHERE book_id = p_book_id
    FOR UPDATE;

    -- If book does not exist, rollback and exit
    IF v_available IS NULL THEN
        ROLLBACK;
        SELECT 'Error: Book does not exist.' AS message;
        LEAVE proc_label; -- Exit the procedure
    END IF;

    -- If book is not available (0 or less copies), rollback and exit
    IF v_available <= 0 THEN
        ROLLBACK;
        SELECT 'Error: Book not available for issuing.' AS message;
        LEAVE proc_label; -- Exit the procedure
    END IF;

    -- Get the maximum transaction_id to generate a new unique ID
    SELECT IFNULL(MAX(transaction_id), 0) INTO v_max_transaction_id FROM TRANSACTIONS;

    -- Insert a new transaction record
    INSERT INTO TRANSACTIONS (
        transaction_id, member_id, book_id, issue_date, due_date, return_date, fine_amount, status
    ) VALUES (
        v_max_transaction_id + 1,        -- New transaction ID
        p_member_id,                     -- Member ID
        p_book_id,                       -- Book ID
        CURDATE(),                       -- Current date as issue date
        DATE_ADD(CURDATE(), INTERVAL 14 DAY), -- Due date (14 days from issue date)
        NULL,                            -- Return date is initially NULL
        0.00,                            -- Initial fine amount is 0
        'Pending'                        -- Transaction status
    );

    -- Decrease the count of available copies for the issued book
    UPDATE BOOKS
    SET available_copies = available_copies - 1
    WHERE book_id = p_book_id;

    COMMIT; -- Commit the transaction if all operations are successful

    -- Return a success message with the new transaction ID
    SELECT CONCAT('Book issued successfully. Transaction ID: ', v_max_transaction_id + 1) AS message;

END proc_label $$

DELIMITER ;


-- 4.2: Function to Calculate Fine
-- This function calculates the fine for a given transaction.
-- It considers the due date and return date (or current date if not returned)
-- and applies a fine of ₹5 per overdue day.
DELIMITER $$

CREATE FUNCTION CALCULATE_FINE(p_transaction_id INT)
RETURNS DECIMAL(6,2)
DETERMINISTIC
BEGIN
    DECLARE v_due_date DATE;
    DECLARE v_return_date DATE;
    DECLARE v_today DATE;
    DECLARE v_overdue_days INT DEFAULT 0;
    DECLARE v_fine DECIMAL(6,2) DEFAULT 0.00;

    SET v_today = CURDATE(); -- Get the current date

    -- Retrieve due_date and return_date for the specified transaction
    SELECT due_date, return_date
    INTO v_due_date, v_return_date
    FROM TRANSACTIONS
    WHERE transaction_id = p_transaction_id;

    -- Calculate overdue days based on return_date or current date
    IF v_return_date IS NOT NULL THEN
        -- If the book has been returned, calculate days between return and due date
        SET v_overdue_days = DATEDIFF(v_return_date, v_due_date);
    ELSE
        -- If the book is not yet returned, calculate days between today and due date
        SET v_overdue_days = DATEDIFF(v_today, v_due_date);
    END IF;

    -- If there are overdue days, calculate the fine (₹5 per day)
    IF v_overdue_days > 0 THEN
        SET v_fine = v_overdue_days * 5;
    ELSE
        SET v_fine = 0.00; -- No fine if not overdue
    END IF;

    RETURN v_fine; -- Return the calculated fine
END $$

DELIMITER ;

-- Example of calling the CALCULATE_FINE function
SELECT CALCULATE_FINE(1) AS fine_for_transaction_1;


-- 4.3: Trigger to Update Available Copies After Book Return
-- This trigger automatically updates the 'available_copies' in the BOOKS table
-- whenever a transaction's status changes to 'Returned'.
DELIMITER $$

CREATE TRIGGER update_available_copies_after_return
AFTER UPDATE ON TRANSACTIONS
FOR EACH ROW
BEGIN
    -- Check if the old status was not 'Returned' and the new status is 'Returned'
    IF OLD.status <> 'Returned' AND NEW.status = 'Returned' THEN
        -- Increment the available_copies for the book that was returned
        UPDATE BOOKS
        SET available_copies = available_copies + 1
        WHERE book_id = NEW.book_id;
    END IF;
END $$

DELIMITER ;


-- User Management: Create Users
-- These commands create two new users: 'librarian' and 'student_user'.
CREATE USER 'librarian'@'localhost' IDENTIFIED BY 'lib_password123';
CREATE USER 'student_user'@'localhost' IDENTIFIED BY 'student_password123';


-- User Management: Grant Privileges
-- These commands assign specific privileges to the newly created users.
-- 'librarian' gets full access to the 'Library_Management_System' database.
-- 'student_user' gets read-only access (SELECT) on the 'BOOKS' table.
GRANT ALL PRIVILEGES ON Library_Management_System.* TO 'librarian'@'localhost';
GRANT SELECT ON Library_Management_System.BOOKS TO 'student_user'@'localhost';

-- Apply changes to the privilege tables
FLUSH PRIVILEGES;

-- User Management: Drop Users (Example - for cleanup or re-creation)
-- These commands are typically used to remove existing users.
-- They are included here for completeness, demonstrating how to clean up users.
DROP USER 'librarian'@'localhost';
DROP USER 'student_user'@'localhost';

-- User Management: Re-create Users (if they were dropped)
-- These commands re-create the users after they have been dropped,
-- demonstrating the full cycle of user management.
CREATE USER 'librarian'@'localhost' IDENTIFIED BY 'lib_password123';
CREATE USER 'student_user'@'localhost' IDENTIFIED BY 'student_password123';

-- User Management: Re-grant Privileges (after re-creation)
-- Privileges must be re-granted if users are re-created.
GRANT ALL PRIVILEGES ON Library_Management_System.* TO 'librarian'@'localhost';
GRANT SELECT ON Library_Management_System.BOOKS TO 'student_user'@'localhost';
FLUSH PRIVILEGES;


-- task 2.1: Data Querying

-- 1. List all books with their available copies where available copies are less than total copies
-- This query identifies books that have been borrowed at least once by comparing available copies to total copies.
SELECT book_id, title, total_copies, available_copies
FROM BOOKS
WHERE available_copies < total_copies;


-- 2. Find members who have overdue books
-- This query joins MEMBERS and TRANSACTIONS tables to find members with transactions
-- where the due_date has passed and the book status is 'Overdue'.
SELECT M.member_id, M.first_name, M.last_name, T.book_id, T.due_date
FROM MEMBERS M
JOIN TRANSACTIONS T ON M.member_id = T.member_id
WHERE T.due_date < CURDATE() AND T.status = 'Overdue';

-- 3. Display the top 5 most borrowed books with their borrow count
-- This query counts the number of transactions for each book, groups them by book,
-- and then orders them in descending order to find the top 5 most borrowed books.
SELECT B.book_id, B.title, COUNT(T.transaction_id) AS borrow_count
FROM BOOKS B
JOIN TRANSACTIONS T ON B.book_id = T.book_id
GROUP BY B.book_id, B.title
ORDER BY borrow_count DESC
LIMIT 5;

-- 4. Show members who have never returned a book on time
-- This query finds distinct members who have at least one transaction where the return_date
-- is later than the due_date, indicating they returned a book late.
SELECT DISTINCT M.member_id, M.first_name, M.last_name
FROM MEMBERS M
JOIN TRANSACTIONS T ON M.member_id = T.member_id
WHERE T.return_date > T.due_date;


-- 2.2: Data Manipulation

-- 1. Update fine amounts for all overdue transactions (₹5 per day after due date)
-- This command sets SQL_SAFE_UPDATES to 0 to allow updates without a WHERE clause
-- that uses a key column, then updates the fine_amount for transactions where
-- the return_date is after the due_date, calculating the fine at ₹5 per day.
SET SQL_SAFE_UPDATES = 0;

UPDATE TRANSACTIONS
SET fine_amount = DATEDIFF(return_date, due_date) * 5
WHERE return_date > due_date;

-- 2. Insert a new member with membership validation (no duplicate email or phone)
-- This INSERT statement uses a subquery with NOT EXISTS to prevent inserting a new member
-- if an existing member already has the same email or phone number, ensuring data integrity.
INSERT INTO MEMBERS (member_id, first_name, last_name, email, phone, address, membership_date, membership_type)
SELECT 16, 'Rafi', 'Hasan', 'rafi@example.com', '01234567906', 'Narsingdi, BD', CURDATE(), 'Student'
WHERE NOT EXISTS (
    SELECT 1 FROM MEMBERS WHERE email = 'rafi@example.com' OR phone = '01234567906'
);

-- 3. Archive completed transactions older than 2 years to a separate table
-- Step 1: Create an archive table with the same structure as the TRANSACTIONS table but no data.
CREATE TABLE IF NOT EXISTS TRANSACTION_ARCHIVE AS
SELECT * FROM TRANSACTIONS WHERE 1 = 0;

-- Step 2: Insert old returned transactions into the archive table and then delete them from the main TRANSACTIONS table.
-- This helps in managing the size of the main transactions table and improving performance.
INSERT INTO TRANSACTION_ARCHIVE
SELECT * FROM TRANSACTIONS
WHERE status = 'Returned' AND return_date < CURDATE() - INTERVAL 2 YEAR;

DELETE FROM TRANSACTIONS
WHERE status = 'Returned' AND return_date < CURDATE() - INTERVAL 2 YEAR;

-- 4. Update book categories based on publication year ranges
-- This UPDATE statement assigns categories ('Classic', 'Standard', 'Modern') to books
-- based on their publication year, using a CASE statement for conditional logic.
UPDATE BOOKS
SET category = CASE
    WHEN YEAR(publication_year) < 2000 THEN 'Classic'
    WHEN YEAR(publication_year) BETWEEN 2000 AND 2010 THEN 'Standard'
    ELSE 'Modern'
END;


-- 3.1: Joins

-- 1. Display transaction history with member details and book information for all overdue books using INNER JOIN
-- This query combines data from TRANSACTIONS, MEMBERS, and BOOKS tables
-- to provide a comprehensive view of overdue transactions, including details
-- about the member and the book involved.
SELECT
    T.transaction_id,
    M.member_id, M.first_name, M.last_name,
    B.book_id, B.title, B.category,
    T.issue_date, T.due_date, T.return_date, T.status
FROM TRANSACTIONS T
INNER JOIN MEMBERS M ON T.member_id = M.member_id
INNER JOIN BOOKS B ON T.book_id = B.book_id
WHERE T.status = 'Overdue';


-- 2. Show all books and their transaction count (including books never borrowed) using LEFT JOIN
-- This query uses a LEFT JOIN to ensure all books are listed, even if they have no associated transactions.
-- It counts the number of transactions for each book, showing books never borrowed with a count of 0.
SELECT
    B.book_id, B.title, COUNT(T.transaction_id) AS transaction_count
FROM BOOKS B
LEFT JOIN TRANSACTIONS T ON B.book_id = T.book_id
GROUP BY B.book_id, B.title
ORDER BY transaction_count DESC;


-- 3. Find members who have borrowed books from the same category as other members using SELF JOIN
-- This complex query uses multiple joins, including a self-join on TRANSACTIONS and MEMBERS,
-- to identify pairs of distinct members who have borrowed books belonging to the same category.
SELECT DISTINCT
    M1.member_id AS member1_id, M1.first_name AS member1_name,
    M2.member_id AS member2_id, M2.first_name AS member2_name,
    B1.category
FROM TRANSACTIONS T1
JOIN MEMBERS M1 ON T1.member_id = M1.member_id
JOIN BOOKS B1 ON T1.book_id = B1.book_id

JOIN TRANSACTIONS T2 ON B1.category = (
    SELECT B2.category FROM BOOKS B2 WHERE B2.book_id = T2.book_id
)
JOIN MEMBERS M2 ON T2.member_id = M2.member_id

WHERE M1.member_id <> M2.member_id;


-- 4. List all possible member-book combinations for recommendation system using CROSS JOIN (limit to 50 results)
-- A CROSS JOIN generates every possible combination of rows from two tables.
-- This is useful for generating potential recommendations, limited to 50 results for practicality.
SELECT
    M.member_id, M.first_name, M.last_name,
    B.book_id, B.title, B.category
FROM MEMBERS M
CROSS JOIN BOOKS B
LIMIT 50;


-- 3.2: Subqueries

-- 1. Find all books that have been borrowed more times than the average borrowing rate across all books
-- This query uses nested subqueries to first calculate the borrow count for each book,
-- then the average borrow count across all books, and finally selects books
-- whose individual borrow count exceeds this average.
SELECT book_id, title
FROM BOOKS
WHERE book_id IN (
    SELECT book_id
    FROM TRANSACTIONS
    GROUP BY book_id
    HAVING COUNT(*) > (
        SELECT AVG(borrow_count)
        FROM (
            SELECT COUNT(*) AS borrow_count
            FROM TRANSACTIONS
            GROUP BY book_id
        ) AS borrow_stats
    )
);


-- 2. List members whose total fine amount is greater than the average fine paid by their membership type
-- This query uses subqueries to calculate each member's total fine and the average fine
-- for each membership type, then identifies members whose total fine is above their type's average.
SELECT member_id, first_name, last_name, total_fine
FROM (
    SELECT M.member_id, M.first_name, M.last_name, M.membership_type,
            SUM(T.fine_amount) AS total_fine
    FROM MEMBERS M
    JOIN TRANSACTIONS T ON M.member_id = T.member_id
    GROUP BY M.member_id, M.first_name, M.last_name, M.membership_type
) AS member_fines
WHERE total_fine > (
    SELECT AVG(total_fine)
    FROM (
        SELECT M.member_id, M.membership_type, SUM(T.fine_amount) AS total_fine
        FROM MEMBERS M
        JOIN TRANSACTIONS T ON M.member_id = T.member_id
        GROUP BY M.member_id, M.membership_type
    ) AS type_fines
    WHERE type_fines.membership_type = member_fines.membership_type
);


-- 3. Display books that are currently available but belong to the same category as the most borrowed book
-- This query identifies the category of the most borrowed book using a subquery,
-- then selects all currently available books that fall into that same category.
SELECT book_id, title, category
FROM BOOKS
WHERE available_copies > 0
AND category = (
    SELECT B.category
    FROM BOOKS B
    JOIN TRANSACTIONS T ON B.book_id = T.book_id
    GROUP BY B.category
    ORDER BY COUNT(*) DESC
    LIMIT 1
);


-- 4. Find the second most active member (by transaction count)
-- This query uses nested subqueries to determine the second highest transaction count
-- among all members and then selects the member(s) associated with that count.
SELECT member_id, first_name, last_name, txn_count
FROM (
    SELECT M.member_id, M.first_name, M.last_name, COUNT(T.transaction_id) AS txn_count
    FROM MEMBERS M
    JOIN TRANSACTIONS T ON M.member_id = T.member_id
    GROUP BY M.member_id, M.first_name, M.last_name
) AS member_txns
WHERE txn_count = (
    -- Find the second highest transaction count
    SELECT MAX(txn_count) FROM (
        SELECT COUNT(transaction_id) AS txn_count
        FROM TRANSACTIONS
        GROUP BY member_id
        HAVING COUNT(transaction_id) < (
            -- Highest transaction count
            SELECT MAX(txn_count_inner) FROM (
                SELECT COUNT(transaction_id) AS txn_count_inner
                FROM TRANSACTIONS
                GROUP BY member_id
            ) AS all_txns_inner
        )
    ) AS second_max
);


-- 3.3: Aggregate & Window Functions

-- 1. Calculate running total of fines collected by month using window functions
-- This query calculates the monthly fine amount and then uses a window function
-- (SUM() OVER (ORDER BY ...)) to compute a running total of fines collected over time.
SELECT
    DATE_FORMAT(return_date, '%Y-%m') AS month,
    SUM(fine_amount) AS monthly_fine,
    SUM(SUM(fine_amount)) OVER (ORDER BY DATE_FORMAT(return_date, '%Y-%m')) AS running_total
FROM TRANSACTIONS
WHERE fine_amount > 0
GROUP BY month
ORDER BY month;

-- 2. Rank members by their borrowing activity within each membership type
-- This query first calculates the borrow count for each member and then uses
-- the RANK() window function to rank members based on their borrowing activity
-- within their respective membership types.
SELECT
    member_id, first_name, last_name, membership_type, borrow_count,
    RANK() OVER (PARTITION BY membership_type ORDER BY borrow_count DESC) AS rank_within_type
FROM (
    SELECT M.member_id, M.first_name, M.last_name, M.membership_type, COUNT(T.transaction_id) AS borrow_count
    FROM MEMBERS M
    LEFT JOIN TRANSACTIONS T ON M.member_id = T.member_id
    GROUP BY M.member_id, M.first_name, M.last_name, M.membership_type
) AS sub;


-- 3. Find percentage contribution of each book category to total library transactions
-- This query calculates the number of transactions per book category and then
-- determines each category's percentage contribution to the total number of transactions
-- across the entire library.
SELECT
    B.category,
    COUNT(T.transaction_id) AS category_transaction_count,
    ROUND(100 * COUNT(T.transaction_id) / (SELECT COUNT(*) FROM TRANSACTIONS), 2) AS percentage_contribution
FROM BOOKS B
LEFT JOIN TRANSACTIONS T ON B.book_id = T.book_id
GROUP BY B.category
ORDER BY percentage_contribution DESC;


-- Database and Table Creation
-- These commands set up the database and define the schema for the BOOKS, MEMBERS, and TRANSACTIONS tables.
CREATE DATABASE Library_Management_System;
USE Library_Management_System;

-- BOOKS Table Definition
CREATE TABLE BOOKS (
    book_id INT PRIMARY KEY,
    title VARCHAR(25) NOT NULL,
    author VARCHAR(25),
    publisher VARCHAR(25),
    publication_year DATE NOT NULL,
    isbn VARCHAR(25) UNIQUE,
    category VARCHAR(25),
    total_copies INT,
    available_copies INT,
    price DECIMAL(6,2)
);

-- MEMBERS Table Definition
CREATE TABLE MEMBERS (
    member_id INT PRIMARY KEY,
    first_name VARCHAR(25),
    last_name VARCHAR(25),
    email VARCHAR(25) UNIQUE,
    phone VARCHAR(25),
    address VARCHAR(50),
    membership_date DATE,
    membership_type VARCHAR(10)
);

-- TRANSACTIONS Table Definition
CREATE TABLE TRANSACTIONS (
    transaction_id INT PRIMARY KEY,
    member_id INT,
    book_id INT,
    issue_date DATE,
    due_date DATE,
    return_date DATE,
    fine_amount DECIMAL(6,2),
    status VARCHAR(10),
    FOREIGN KEY (member_id) REFERENCES MEMBERS(member_id),
    FOREIGN KEY (book_id) REFERENCES BOOKS(book_id)
);

-- Data Insertion for BOOKS Table
INSERT INTO BOOKS
VALUES
(1, 'Data Science 101', 'John Smith', 'TechPub', '2020-01-01', 'ISBN001', 'Technology', 5, 3, 49.99),
(2, 'The Great Gatsby', 'F. Scott', 'Scribner', '1925-04-10', 'ISBN002', 'Fiction', 3, 2, 19.99),
(3, 'Python Basics', 'Guido Rossum', 'CodeHouse', '2018-03-15', 'ISBN003', 'Programming', 6, 5, 29.99),
(4, 'Calculus Made Easy', 'Silvanus P.', 'MathBooks', '2005-06-12', 'ISBN004', 'Mathematics', 4, 2, 39.99),
(5, 'Artificial Intelligence', 'Peter Norvig', 'AIWorld', '2010-11-01', 'ISBN005', 'Technology', 5, 4, 59.99),
(6, 'Database Systems', 'Hector Garcia', 'DBBooks', '2012-09-20', 'ISBN006', 'Technology', 6, 5, 54.99),
(7, 'Digital Logic', 'Morris Mano', 'Pearson', '2001-08-10', 'ISBN007', 'Engineering', 4, 2, 34.99),
(8, 'Networking Concepts', 'Andrew Tanenbaum', 'NetPress', '2004-05-23', 'ISBN008', 'Technology', 5, 3, 44.99),
(9, 'English Grammar', 'Raymond Murphy', 'CUP', '2000-01-01', 'ISBN009', 'Language', 6, 4, 24.99),
(10, 'Shakespeare Plays', 'William S.', 'LitWorld', '1999-07-15', 'ISBN010', 'Literature', 3, 1, 29.99),
(11, 'Physics for Beginners', 'Isaac Newton', 'SciHouse', '2010-05-10', 'ISBN011', 'Science', 5, 3, 39.00),
(12, 'Organic Chemistry', 'Morrison & Boyd', 'ChemPress', '2003-03-12', 'ISBN012', 'Science', 4, 2, 49.99),
(13, 'Modern Politics', 'John Locke', 'PoliPub', '2015-10-20', 'ISBN013', 'Politics', 4, 3, 32.00),
(14, 'Intro to Philosophy', 'Plato', 'ThinkHouse', '2009-01-01', 'ISBN014', 'Philosophy', 3, 2, 22.00),
(15, 'Machine Learning', 'Tom Mitchell', 'MLBooks', '2011-02-14', 'ISBN015', 'Technology', 6, 5, 55.55),
(16, 'C Programming', 'Dennis Ritchie', 'TechPress', '1995-06-30', 'ISBN016', 'Programming', 5, 3, 27.99),
(17, 'Java in Depth', 'James Gosling', 'CodeWorld', '2007-04-18', 'ISBN017', 'Programming', 6, 4, 45.99),
(18, 'Statistical Methods', 'R.A. Fisher', 'MathsToday', '2002-11-20', 'ISBN018', 'Mathematics', 5, 3, 40.00),
(19, 'Business Ethics', 'Linda Trevino', 'BizBooks', '2016-09-01', 'ISBN019', 'Business', 4, 2, 38.99),
(20, 'World History', 'Howard Zinn', 'HistPress', '1998-03-05', 'ISBN020', 'History', 5, 3, 35.00);

-- Data Insertion for MEMBERS Table
INSERT INTO MEMBERS VALUES
(1, 'Alice', 'Johnson', 'alice@example.com', '01234567891', 'Dhaka, BD', '2022-01-01', 'Student'),
(2, 'Bob', 'Smith', 'bob@example.com', '01234567892', 'Chittagong, BD', '2022-02-01', 'Faculty'),
(3, 'Charlie', 'Brown', 'charlie@example.com', '01234567893', 'Rajshahi, BD', '2022-03-01', 'Student'),
(4, 'David', 'Lee', 'david@example.com', '01234567894', 'Khulna, BD', '2022-04-01', 'Staff'),
(5, 'Eve', 'Taylor', 'eve@example.com', '01234567895', 'Barishal, BD', '2022-05-01', 'Student'),
(6, 'Frank', 'Wright', 'frank@example.com', '01234567896', 'Sylhet, BD', '2022-06-01', 'Faculty'),
(7, 'Grace', 'Kim', 'grace@example.com', '01234567897', 'Dhaka, BD', '2022-07-01', 'Student'),
(8, 'Hannah', 'Adams', 'hannah@example.com', '01234567898', 'Dinajpur, BD', '2022-08-01', 'Staff'),
(9, 'Ian', 'Carter', 'ian@example.com', '01234567899', 'Cox’s Bazar, BD', '2022-09-01', 'Faculty'),
(10, 'Jane', 'Doe', 'jane@example.com', '01234567900', 'Rangpur, BD', '2022-10-01', 'Student'),
(11, 'Kyle', 'Bennett', 'kyle@example.com', '01234567901', 'Gazipur, BD', '2022-11-01', 'Staff'),
(12, 'Laura', 'Scott', 'laura@example.com', '01234567902', 'Dhaka, BD', '2022-12-01', 'Faculty'),
(13, 'Mike', 'Turner', 'mike@example.com', '01234567903', 'Bogura, BD', '2023-01-01', 'Student'),
(14, 'Nina', 'Parker', 'nina@example.com', '01234567904', 'Jessore, BD', '2023-02-01', 'Student'),
(15, 'Omar', 'Ali', 'omar@example.com', '01234567905', 'Dhaka, BD', '2023-03-01', 'Staff');

-- Data Insertion for TRANSACTIONS Table
INSERT INTO TRANSACTIONS VALUES
(1, 1, 1, '2025-06-01', '2025-06-10', '2025-06-09', 0.00, 'Returned'),
(2, 2, 2, '2025-06-03', '2025-06-13', NULL, 0.00, 'Pending'),
(3, 3, 3, '2025-05-25', '2025-06-05', '2025-06-08', 5.00, 'Returned'),
(4, 4, 4, '2025-06-01', '2025-06-10', NULL, 0.00, 'Overdue'),
(5, 5, 5, '2025-06-02', '2025-06-12', '2025-06-11', 0.00, 'Returned'),
(6, 6, 6, '2025-06-04', '2025-06-14', NULL, 0.00, 'Pending'),
(7, 7, 7, '2025-05-20', '2025-06-01', '2025-06-03', 4.00, 'Returned'),
(8, 8, 8, '2025-06-06', '2025-06-16', NULL, 0.00, 'Pending'),
(9, 9, 9, '2025-06-01', '2025-06-10', NULL, 0.00, 'Overdue'),
(10, 10, 10, '2025-06-02', '2025-06-12', '2025-06-12', 0.00, 'Returned'),
(11, 11, 11, '2025-06-03', '2025-06-13', NULL, 0.00, 'Pending'),
(12, 12, 12, '2025-06-01', '2025-06-10', NULL, 0.00, 'Overdue'),
(13, 13, 13, '2025-06-05', '2025-06-15', '2025-06-14', 0.00, 'Returned'),
(14, 14, 14, '2025-06-04', '2025-06-14', NULL, 0.00, 'Pending'),
(15, 15, 15, '2025-06-06', '2025-06-16', NULL, 0.00, 'Pending'),
(16, 1, 16, '2025-06-07', '2025-06-17', NULL, 0.00, 'Pending'),
(17, 2, 17, '2025-06-08', '2025-06-18', NULL, 0.00, 'Pending'),
(18, 3, 18, '2025-06-09', '2025-06-19', NULL, 0.00, 'Pending'),
(19, 4, 19, '2025-06-10', '2025-06-20', NULL, 0.00, 'Pending'),
(20, 5, 20, '2025-06-11', '2025-06-21', NULL, 0.00, 'Pending'),
(21, 6, 1, '2025-05-10', '2025-05-20', '2025-05-21', 2.00, 'Returned'),
(22, 7, 2, '2025-05-01', '2025-05-10', '2025-05-15', 10.00, 'Returned'),
(23, 8, 3, '2025-05-20', '2025-06-01', '2025-06-05', 6.00, 'Returned'),
(24, 9, 4, '2025-06-10', '2025-06-20', NULL, 0.00, 'Pending'),
(25, 10, 5, '2025-06-11', '2025-06-21', NULL, 0.00, 'Pending');
