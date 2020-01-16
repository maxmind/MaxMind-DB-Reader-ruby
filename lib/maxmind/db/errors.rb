# frozen_string_literal: true

module MaxMind
  class DB
    # An InvalidDatabaseError means the {MaxMind
    # DB}[https://maxmind.github.io/MaxMind-DB/] file is corrupt or invalid.
    class InvalidDatabaseError < RuntimeError
    end
  end
end
