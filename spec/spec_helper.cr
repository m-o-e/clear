require "spec"

require "../src/clear"

# Avoiding migration number collisions
MIGRATION_SPEC_MIGRATION_UID = 0x0100000000000000_u64
MIGRATION_SPEC_MODEL_UID     = 0x0200000000000000_u64

def get_uid(name : String)

end


class ::Crypto::Bcrypt::Password
  # Redefine the default cost to 4 (the minimum allowed) to accelerate greatly the tests.
  DEFAULT_COST = 4
end

def initdb
  system("echo \"DROP DATABASE IF EXISTS clear_spec;\" | psql -U postgres 2>&1 1>/dev/null")
  system("echo \"CREATE DATABASE clear_spec;\" | psql -U postgres 2>&1 1>/dev/null")

  system("echo \"DROP DATABASE IF EXISTS clear_secondary_spec;\" | psql -U postgres 2>&1 1>/dev/null")
  system("echo \"CREATE DATABASE clear_secondary_spec;\" | psql -U postgres 2>&1 1>/dev/null")
  system("echo \"CREATE TABLE models_post_stats (id serial PRIMARY KEY, post_id INTEGER);\" | psql -U postgres clear_secondary_spec 2>&1 1>/dev/null")

  Clear::SQL.init("postgres://postgres@localhost/clear_spec", connection_pool_size: 5)
  Clear::SQL.init("secondary", "postgres://postgres@localhost/clear_secondary_spec", connection_pool_size: 5)

  {% if flag?(:quiet) %}
    Log.builder.bind "clear.*", Log::Severity::Warning, Log::IOBackend.new
  {% else %}
    Log.builder.bind "clear.*", Log::Severity::Debug, Log::IOBackend.new
  {% end %}
end

def reinit_migration_manager
  Clear::Migration::Manager.instance.reinit!
end

def temporary(&block)
  Clear::SQL.with_savepoint do
    yield
    Clear::SQL.rollback
  end
end

initdb
