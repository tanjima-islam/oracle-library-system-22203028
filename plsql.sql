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
