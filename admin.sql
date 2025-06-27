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
