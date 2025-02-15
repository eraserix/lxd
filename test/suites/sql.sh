# Test the lxd sql command.
test_sql() {
  # Invalid arguments
  ! lxd sql foo "SELECT * FROM CONFIG" || false
  ! lxd sql global "" || false

  # Local database query
  lxd sql local "SELECT * FROM config" | grep -q "core.https_address"

  # Global database query
  lxd sql global "SELECT * FROM config" | grep -q "core.trust_password"

  # Global database insert
  lxd sql global "INSERT INTO config(key,value) VALUES('core.https_allowed_credentials','true')" | grep -q "Rows affected: 1"
  lxd sql global "DELETE FROM config WHERE key='core.https_allowed_credentials'" | grep -q "Rows affected: 1"

  # Standard input
  echo "SELECT * FROM config" | lxd sql global - | grep -q "core.trust_password"

  # Multiple queries
  lxd sql global "SELECT * FROM config; SELECT * FROM instances" | grep -q "=> Query 0"

  # Local database dump
  SQLITE_DUMP="${TEST_DIR}/dump.db"
  lxd sql local .dump | sqlite3 "${SQLITE_DUMP}"
  sqlite3 "${SQLITE_DUMP}" "SELECT * FROM patches" | grep -q dnsmasq_entries_include_device_name
  rm -f "${SQLITE_DUMP}"

  # Local database schema dump
  SQLITE_DUMP="${TEST_DIR}/dump.db"
  lxd sql local .schema | sqlite3 "${SQLITE_DUMP}"
  [ "$(sqlite3 "${SQLITE_DUMP}" 'SELECT * FROM schema' | wc -l)" = "0" ]
  [ "$(sqlite3 "${SQLITE_DUMP}" 'SELECT * FROM patches' | wc -l)" = "0" ]
  rm -f "${SQLITE_DUMP}"

  # Global database dump
  SQLITE_DUMP="${TEST_DIR}/dump.db"
  GLOBAL_DUMP=$(lxd sql global .dump)
  echo "$GLOBAL_DUMP" | grep "CREATE TRIGGER" # ensure triggers are captured.
  echo "$GLOBAL_DUMP" | grep "CREATE INDEX"   # ensure indices are captured.
  echo "$GLOBAL_DUMP" | grep "CREATE VIEW"    # ensure views are captured.
  echo "$GLOBAL_DUMP" | sqlite3 "${SQLITE_DUMP}"
  sqlite3 "${SQLITE_DUMP}" "SELECT * FROM profiles" | grep -q "Default LXD profile"
  rm -f "${SQLITE_DUMP}"

  # Global database schema dump
  SQLITE_DUMP="${TEST_DIR}/dump.db"
  lxd sql global .schema | sqlite3 "${SQLITE_DUMP}"
  [ "$(sqlite3 "${SQLITE_DUMP}" 'SELECT * FROM schema' | wc -l)" = "0" ]
  [ "$(sqlite3 "${SQLITE_DUMP}" 'SELECT * FROM profiles' | wc -l)" = "0" ]
  rm -f "${SQLITE_DUMP}"

  # Sync the global database to disk
  SQLITE_SYNC="${LXD_DIR}/database/global/db.bin"
  echo SYNC "${SQLITE_SYNC}"
  lxd sql global .sync
  sqlite3 "${SQLITE_SYNC}" "SELECT * FROM schema" | grep -q 1
  sqlite3 "${SQLITE_SYNC}" "SELECT * FROM profiles" | grep -q "Default LXD profile"
}
