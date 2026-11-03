# PostgreSQL 17 Cluster with Read Replica

**Languages:** [English](README.md) | [Polski](README_PL.md)

![Docker](https://img.shields.io/badge/Docker-27.2.0-orange)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v1.29.2--desktop.2-orange)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17-green)

## Overview

This Docker Compose setup creates a PostgreSQL 17 cluster with a primary (read-write) instance and a read replica, providing high availability and read scalability for your database needs.

![Docker-compose Stack](docs/docker-compose-stack.png)

## Features

### PostgreSQL 17 Key Features

PostgreSQL 17 introduces several significant improvements:

- **Enhanced Logical Replication**: Improved performance and reliability for logical replication
- **Better Query Performance**: Optimized query planning and execution
- **Improved Partitioning**: Enhanced table partitioning capabilities
- **Security Enhancements**: New security features and improvements
- **Monitoring Improvements**: Better monitoring and observability tools
- **Performance Optimizations**: Various performance improvements across the board

## ⚠️ Important Disclaimer

**This is a Proof of Concept (PoC) setup and should NOT be used in production environments.**

This setup is intended for:
- Learning purposes
- Development environments
- Testing replication concepts
- Understanding PostgreSQL replication basics

**Production Considerations:**
- This setup lacks proper security hardening
- No backup strategy is implemented
- No monitoring or alerting is configured
- No high availability features beyond basic replication
- No disaster recovery procedures
- No proper network isolation
- No SSL/TLS encryption
- No proper user and role management
- No proper logging and auditing

For production environments, please consider:
- Implementing proper security measures
- Setting up monitoring and alerting
- Configuring proper backup and recovery procedures
- Using a managed database service
- Consulting with database experts
- Following PostgreSQL best practices

### Cluster Features

- Primary (read-write) and read replica setup
- Physical streaming replication with a dedicated replication slot
- Automatic replica bootstrap with `pg_basebackup`
- Automatic replication role and slot creation on first start
- Persistent data storage with named volumes
- Health checks for both instances
- Custom `pg_hba.conf` allowing replication from the replica container

## Architecture

### How Replication Works

This setup implements physical streaming replication between the primary and replica nodes:

1. The primary node (`rmf_classic_sugesstions`) accepts write operations
2. Changes are written to the Write-Ahead Log (WAL)
3. The replica (`rmf_classic_sugesstions_replica`) continuously streams these WAL records
4. The replica applies these changes to maintain an exact copy of the primary
5. The replica operates in hot standby mode, allowing read operations

On the first start, the replica waits for the primary to accept connections and then clones it with `pg_basebackup`. The `-R` option creates `standby.signal` and configures `primary_conninfo` and `primary_slot_name` automatically.

On later starts, the replica detects the existing `standby.signal` file and skips the clone, resuming WAL streaming from the primary.

### Docker Compose Configuration

The `docker-compose.yml` file manages two PostgreSQL containers:

- **Primary Node (`rmf_classic_sugesstions`)**:
  - Published on host port `9874`
  - Listens on container port `5432`
  - Handles read/write operations
  - Creates the `replica` role and the `replica_slot` physical replication slot on first initialization

- **Read Replica (`rmf_classic_sugesstions_replica`)**:
  - Published on host port `9873`
  - Automatically clones and connects to the primary
  - Handles read-only operations
  - Maintains an exact copy of the primary data

The configuration includes:
- Health checks for both instances
- Persistent volumes for data storage
- Automatic replication setup
- Dedicated network for container communication

### Project Files

| Path | Purpose |
| --- | --- |
| `docker-compose.yml` | Defines the primary, replica, volumes and health checks |
| `.env` | Database name, user and password (copied from `.env.example`) |
| `initdb.d/00_init.sh` | Creates the `replica` role and `replica_slot` on first initialization |
| `config/pg_hba.conf` | Authentication rules, including replication from the replica container |

> The primary container uses `config/pg_hba.conf` via the `hba_file` setting. Without the replication entry, connections fail with `no pg_hba.conf entry for replication connection`.

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/ArekSawicki/postgres-docker-compose-cluster.git
cd postgres-docker-compose-cluster
```

2. Create your environment file:
```bash
cp .env.example .env
```

Then adjust `POSTGRES_DB`, `POSTGRES_USER` and `POSTGRES_PASSWORD` if needed. The replica reuses these values when connecting to the primary.

3. Start the cluster:
```bash
docker compose up -d
```

4. Verify the services are running:
```bash
docker compose ps
```

5. (Optional) Follow the replica bootstrap logs:
```bash
docker compose logs -f rmf_classic_sugesstions_replica
```

## Usage

### Connection Details

| Instance | Host | Port | Access |
| --- | --- | --- | --- |
| Primary | `localhost` | `9874` | Read / write |
| Replica | `localhost` | `9873` | Read-only |

Use the values from your `.env` file as the database name, user and password. In the examples below `rmf_classic_sugesstions` is used as the database name and `postgres` as the superuser.

### Checking Replication Status

```bash
# Connect to the primary
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "SELECT * FROM pg_stat_replication;"

# Connect to the replica
docker compose exec rmf_classic_sugesstions_replica psql -U postgres -d rmf_classic_sugesstions -c "SELECT pg_is_in_recovery();"
```

`pg_is_in_recovery()` should return `t` on the replica and `f` on the primary.

You can also inspect the replication slot on the primary:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "SELECT slot_name, active FROM pg_replication_slots;"
```

### Testing Replication

1. Create a table on the primary:
```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "CREATE TABLE test (id SERIAL PRIMARY KEY, data TEXT);"
```

2. Insert some data on the primary:
```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -d rmf_classic_sugesstions -c "INSERT INTO test (data) VALUES ('test data');"
```

3. Verify the data is replicated to the read replica:
```bash
docker compose exec rmf_classic_sugesstions_replica psql -U postgres -d rmf_classic_sugesstions -c "SELECT * FROM test;"
```

### Stopping the Cluster

To stop the cluster:
```bash
docker compose down
```

To stop and remove volumes (this will delete all data):
```bash
docker compose down -v
```

### Rebuilding the Replica

The replica can be re-cloned from the primary at any time. Stop it and remove its data volume:

```bash
docker compose rm -sf rmf_classic_sugesstions_replica
docker volume rm postgresql17cluster_rmf_classic_sugesstions_replica_data
docker compose up -d rmf_classic_sugesstions_replica
```

> The volume name depends on the Compose project name (the directory name by default).

## Troubleshooting

### `no pg_hba.conf entry for replication connection`

Make sure the primary uses the custom `pg_hba.conf`:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -c "SHOW hba_file;"
```

It should return `/etc/postgresql/pg_hba.conf`. The file must contain:

```conf
host    replication     replica         all                     scram-sha-256
```

### `password authentication failed for user "replica"`

The `replica` role is created only when the primary data directory is initialized for the first time. If the role password does not match `POSTGRES_PASSWORD` (for example, after changing `.env`), update it manually:

```bash
docker compose exec rmf_classic_sugesstions psql -U postgres -c "ALTER ROLE replica WITH REPLICATION LOGIN PASSWORD 'your_password';"
```

### Starting over with a clean cluster

If you do not need to keep the data, remove the volumes and let the initialization scripts run again:

```bash
docker compose down -v
docker compose up -d
```

## Contributing

We welcome contributions! To contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
