# Data layer

Local SQLite cache repository, hosted-database client, and the durable
pending-operation queue. Transactions live here; the domain defines *what* must
be atomic, this layer enforces it. Depends on `domain`.
