## Monkey-patch ActiveRecord to fix compatibility with PostgreSQL 12.5
## See https://stackoverflow.com/a/61684855/641451

require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def set_standard_conforming_strings
        old, self.client_min_messages = client_min_messages, 'warning'
        execute('SET standard_conforming_strings = on', 'SCHEMA') rescue nil
      ensure
        self.client_min_messages = old
      end
    end
  end
end
