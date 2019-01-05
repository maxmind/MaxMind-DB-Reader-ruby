# frozen_string_literal: true

module MaxMind # :nodoc:
  class DB
    # Metadata holds metadata about a {MaxMind
    # DB}[http://maxmind.github.io/MaxMind-DB/] file.
    class Metadata
      # The number of nodes in the database.
      attr_reader :node_count

      # The bit size of a record in the search tree.
      attr_reader :record_size

      # The IP version of the data in the database. A value of 4 means the
      # database only supports IPv4. A database with a value of 6 may support
      # both IPv4 and IPv6 lookups.
      attr_reader :ip_version

      # A string identifying the database type. e.g., "GeoIP2-City".
      attr_reader :database_type

      # An array of locale codes supported by the database.
      attr_reader :languages

      # The major version number of the binary format used when creating the
      # database.
      attr_reader :binary_format_major_version

      # The minor version number of the binary format used when creating the
      # database.
      attr_reader :binary_format_minor_version

      # The Unix epoch for the build time of the database.
      attr_reader :build_epoch

      # A hash from locales to text descriptions of the database.
      attr_reader :description

      # +m+ is a hash representing the metadata map.
      def initialize(map)
        @node_count                  = map['node_count']
        @record_size                 = map['record_size']
        @ip_version                  = map['ip_version']
        @database_type               = map['database_type']
        @languages                   = map['languages']
        @binary_format_major_version = map['binary_format_major_version']
        @binary_format_minor_version = map['binary_format_minor_version']
        @build_epoch                 = map['build_epoch']
        @description                 = map['description']
      end

      # The size of a node in bytes.
      def node_byte_size
        @record_size / 4
      end

      # The size of the search tree in bytes.
      def search_tree_size
        @node_count * node_byte_size
      end
    end
  end
end
