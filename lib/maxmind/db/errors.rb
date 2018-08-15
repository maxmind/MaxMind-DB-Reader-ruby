module MaxMind # :nodoc:
  class DB
    # An InvalidDatabaseError means the {MaxMind
    # DB}[http://maxmind.github.io/MaxMind-DB/] file is corrupt or invalid.
    class InvalidDatabaseError < RuntimeError
    end
  end
end
