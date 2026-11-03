Zmiany co jest w repozytorium orginalne :

- **Primary Node (postgres_primary)**:
  - Runs on port 9874
  - Handles read/write operations
  - Maintains the primary database

- **Read Replica (postgres_replica)**:
  - Runs on port 9873
  - Automatically connects to the primary
  - Handles read-only operations
  - Maintains an exact copy of the primary data
