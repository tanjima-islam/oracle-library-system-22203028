# oracle-library-system-22203028


📚 IUBAT University Library Management System
📦 Final Assignment – Database Course (Oracle / MySQL / SQL Server)
📋 Project Overview
This project serves as the final assignment for the Database course, implementing a fully functional University Library Management System using Oracle Database. The system is designed to manage books, members, and transactions while applying database concepts, normalization, complex queries, PL/SQL programming, and administrative operations.

🎯 Assignment Objectives
This project demonstrates my ability to:

📚 Design and implement a complete relational database system

🧠 Apply ER modeling and normalization techniques

🔍 Develop advanced SQL queries and PL/SQL logic

🛡️ Ensure database security and optimize performance

🧠 Learning Outcomes Achieved
Database Design: Used ER diagrams and normalization (1NF–3NF)

SQL Proficiency: Applied DDL, DML, DCL, and TCL operations

PL/SQL Programming: Wrote reusable procedures, functions, and triggers

Administration: Created roles, managed access, optimized performance

✅ Assignment Completion Breakdown
Part	Description	Marks	Status
1	Database Design & Setup	15	✅
2	Basic SQL Operations	20	✅
3	Advanced SQL Queries	25	✅
4	PL/SQL Programming	25	✅
5	Database Administration	15	✅

🛠️ Technologies Used
Component	Technology
🗄️ Database	Oracle Database
🔠 Query Language	SQL (DML, DDL, DCL, TCL)
⚙️ Procedural Logic	PL/SQL
🛠️ Admin Tools	Oracle SQL Developer

🌟 Key Functional Areas
1️⃣ Comprehensive Data Management
📖 Book Management
Track book title, author, publisher, ISBN

Category classification & inventory tracking

Real-time available copies monitoring

👥 Member Management
Supports student, faculty, staff

Manages contact info, membership date & type

📝 Transaction Management
Issue/return tracking

Fine calculations & due/return date monitoring

2️⃣ Advanced Querying
🔍 Data Retrieval & Manipulation
Available books

Overdue books

Member borrowing history

Top borrowed books

🔗 Join Operations
INNER JOIN: Active borrow logs

LEFT JOIN: Books & their transaction history

SELF JOIN: Referral system support

CROSS JOIN: Full member-book matrix

🧩 Subqueries & Analytics
Most active member

Members with fines

Least borrowed books

SUM(), AVG(), RANK(), NTILE(), LAG()

3️⃣ PL/SQL Automation & Logic
📚 ISSUE_BOOK Procedure
Validates availability

Records transaction

Auto-updates available stock

Handles exceptions

💰 CALCULATE_FINE Function
Takes transaction ID

Computes fine (₹5/day after due date)

Returns exact fine amount

🔄 UPDATE_AVAILABLE_COPIES Trigger
Executes on book return

Increments available_copies

Maintains real-time inventory consistency

4️⃣ Database Administration
🔐 Role-Based Access
librarian: Full access to all tables

student_user: SELECT access on BOOKS only

⚡ Performance Optimization
Indexing key columns

Execution plan analysis

Fine-tuned query strategies

🗃️ File Structure
pgsql
Copy
Edit
oracle-library-system-[student-id]/
│
├── README.md         → Project documentation
└── sql/
    ├── setup.sql     → Tables, constraints, sample data
    ├── queries.sql   → SQL queries (basic + advanced)
    ├── plsql.sql     → Procedures, functions, triggers
    └── admin.sql     → User roles, security, indexing
📁 File Descriptions
setup.sql:

Schema definition for BOOKS, MEMBERS, TRANSACTIONS

Primary/foreign keys and sample data

queries.sql:

Queries for data retrieval, updates, and analytics

Includes joins, subqueries, aggregation, ranking

plsql.sql:

ISSUE_BOOK procedure, CALCULATE_FINE function, trigger logic

Full documentation and parameter explanations

admin.sql:

Creates roles with appropriate privileges

Index creation and security implementations

🚀 How to Run the Project
Connect to Oracle DB:

bash
Copy
Edit
sqlplus username/password@db
Execute scripts in order:

sql
Copy
Edit
@sql/setup.sql       -- Create schema and insert data  
@sql/queries.sql     -- Run core queries  
@sql/plsql.sql       -- Define PL/SQL logic  
@sql/admin.sql       -- User roles and performance setup  
🧱 Database Schema
Table	Description
BOOKS	Book inventory (title, author, ISBN, category, stock)
MEMBERS	Member info (name, contact, type, join date)
TRANSACTIONS	Borrow logs (issue/return dates, fines, status)

📌 Assignment Requirements Met
✅ 20 sample books

✅ 15 members (faculty, students, staff)

✅ 25 transactions (returned, overdue, pending)

🧪 Key Queries Implemented
Books with available_copies < total_copies

Members with overdue books

Top 5 most borrowed books

Members with late returns

Fine calculation (₹5 per day)

⚙️ PL/SQL Implementations
✅ ISSUE_BOOK(member_id, book_id)

✅ CALCULATE_FINE(transaction_id)

✅ Trigger on return to update available_copies

👥 User Roles
Role	Access
librarian	Full CRUD access
student_user	SELECT on BOOKS
