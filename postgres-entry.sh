#!/bin/bash
set -e

# variable for the PG conf location because we're working on it so much
PGCONF="/var/lib/postgresql/data/postgresql.conf"

# Settings to allow 2GB
sed -i 's/#*kernel.shmmax = .*/kernel.shmmax = 2147483648/' /etc/sysctl.d/30-postgresql-shm.conf
sed -i 's/#*kernel.shmall = .*/kernel.shmmax = 524288/' /etc/sysctl.d/30-postgresql-shm.conf
sysctl -p # doesn't work, what's the sysctl command?

sed -i 's/#*shared_buffers = .*/shared_buffers = 1GB/' $PGCONF
# Set to about 50% of system memory
sed -i 's/#*effective_cache_size = .*/effective_cache_size = 8GB/' $PGCONF

# If you have the RAM, 1GB is good
sed -i 's/#*maintenance_work_mem = .*/maintenance_work_mem = 256MB/' $PGCONF

# More helps speed up rendering queries
sed -i 's/#*work_mem = .*/work_mem = 32MB/' $PGCONF

# Suggested parameters for bulk loading
sed -i 's/#*checkpoint_segments = .*/checkpoint_segments = 256/' $PGCONF
sed -i 's/#*checkpoint_completion_target = .*/checkpoint_completion_target = 0.9/' $PGCONF

# Parameter tuning
sed -i 's/#*random_page_cost = .*/random_page_cost = 2.0/' $PGCONF
# On older PG versions increase cpu_tuple_cost to 0.05-0.10

# Autovacuum tuning to minimize bloat
sed -i 's/#*autovacuum_vacuum_scale_factor = .*/autovacuum_vacuum_scale_factor = 0.04/' $PGCONF
sed -i 's/#*autovacuum_analyze_scale_factor = .*/autovacuum_analyze_scale_factor = 0.02/' $PGCONF

gosu postgres postgres --single -jE <<-EOL
  CREATE USER "$OSM_USER";
EOL

gosu postgres postgres --single -jE <<-EOL
  CREATE DATABASE "$OSM_DB";
EOL

gosu postgres postgres --single -jE <<-EOL
  GRANT ALL ON DATABASE "$OSM_DB" TO "$OSM_USER";
EOL

# Postgis extension cannot be created in single user mode.
# So we will do it the kludge way by starting the server,
# updating the DB, then shutting down the server so the
# rest of the docker-postgres init scripts can finish.

gosu postgres pg_ctl -w start
gosu postgres psql "$OSM_DB" <<-EOL
  CREATE EXTENSION postgis;
  CREATE EXTENSION hstore;
  ALTER TABLE geometry_columns OWNER TO "$OSM_USER";
  ALTER TABLE spatial_ref_sys OWNER TO "$OSM_USER";
EOL
gosu postgres pg_ctl stop
