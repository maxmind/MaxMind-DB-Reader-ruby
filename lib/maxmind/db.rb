# frozen_string_literal: true

require 'ipaddr'
require 'maxmind/db/decoder'
require 'maxmind/db/errors'
require 'maxmind/db/file_reader'
require 'maxmind/db/memory_reader'
require 'maxmind/db/metadata'

module MaxMind
  # DB provides a way to read {MaxMind DB
  # files}[https://maxmind.github.io/MaxMind-DB/].
  #
  # {MaxMind DB}[https://maxmind.github.io/MaxMind-DB/] is a binary file format
  # that stores data indexed by IP address subnets (IPv4 or IPv6).
  #
  # This class is a pure Ruby implementation of a reader for the format.
  #
  # == Example
  #
  #   require 'maxmind/db'
  #
  #   reader = MaxMind::DB.new('GeoIP2-City.mmdb', mode: MaxMind::DB::MODE_MEMORY)
  #
  #   record = reader.get('1.1.1.1')
  #   if record.nil?
  #     puts '1.1.1.1 was not found in the database'
  #   else
  #     puts record['country']['iso_code']
  #     puts record['country']['names']['en']
  #   end
  #
  #   reader.close
  class DB
    # Choose the default method to open the database. Currently the default is
    # MODE_FILE.
    MODE_AUTO = :MODE_AUTO
    # Open the database as a regular file and read on demand.
    MODE_FILE = :MODE_FILE
    # Read the database into memory. This is faster than MODE_FILE but causes
    # increased memory use.
    MODE_MEMORY = :MODE_MEMORY
    # Treat the database parameter as containing a database already read into
    # memory. It must be a binary string. This primarily exists for testing.
    #
    # @!visibility private
    MODE_PARAM_IS_BUFFER = :MODE_PARAM_IS_BUFFER

    DATA_SECTION_SEPARATOR_SIZE = 16
    private_constant :DATA_SECTION_SEPARATOR_SIZE
    METADATA_START_MARKER = "\xAB\xCD\xEFMaxMind.com".b.freeze
    private_constant :METADATA_START_MARKER
    METADATA_START_MARKER_LENGTH = 14
    private_constant :METADATA_START_MARKER_LENGTH
    METADATA_MAX_SIZE = 131_072
    private_constant :METADATA_MAX_SIZE

    # Return the metadata associated with the {MaxMind
    # DB}[https://maxmind.github.io/MaxMind-DB/]
    #
    # @return [MaxMind::DB::Metadata]
    attr_reader :metadata

    # Create a DB. A DB provides a way to read {MaxMind DB
    # files}[https://maxmind.github.io/MaxMind-DB/]. If you're performing
    # multiple lookups, it's most efficient to create one DB and reuse it.
    #
    # Once created, the DB is safe to use for lookups from multiple threads. It
    # is safe to use after forking only if you use MODE_MEMORY or if your
    # version of Ruby supports IO#pread.
    #
    # @param database [String] a path to a {MaxMind
    #   DB}[https://maxmind.github.io/MaxMind-DB/].
    #
    # @param options [Hash<Symbol, Symbol>] options controlling the behavior of
    #   the DB.
    #
    # @option options [Symbol] :mode Defines how to open the database. It may
    #   be one of MODE_AUTO, MODE_FILE, or MODE_MEMORY. If you don't provide
    #   one, DB uses MODE_AUTO. Refer to the definition of those constants for
    #   an explanation of their meaning.
    #
    # @raise [InvalidDatabaseError] if the database is corrupt or invalid.
    #
    # @raise [ArgumentError] if the mode is invalid.
    def initialize(database, options = {})
      options[:mode] = MODE_AUTO unless options.key?(:mode)

      case options[:mode]
      when MODE_AUTO, MODE_FILE
        @io = FileReader.new(database)
      when MODE_MEMORY
        @io = MemoryReader.new(database)
      when MODE_PARAM_IS_BUFFER
        @io = MemoryReader.new(database, is_buffer: true)
      else
        raise ArgumentError, 'Invalid mode'
      end

      begin
        @size = @io.size

        metadata_start = find_metadata_start
        metadata_decoder = Decoder.new(@io, metadata_start)
        metadata_map, = metadata_decoder.decode(metadata_start)
        @metadata = Metadata.new(metadata_map)
        @decoder = Decoder.new(@io, @metadata.search_tree_size +
                               DATA_SECTION_SEPARATOR_SIZE)

        # Store copies as instance variables to reduce method calls.
        @ip_version       = @metadata.ip_version
        @node_count       = @metadata.node_count
        @node_byte_size   = @metadata.node_byte_size
        @record_size      = @metadata.record_size
        @search_tree_size = @metadata.search_tree_size

        @ipv4_start = nil
        # Find @ipv4_start up front. If we don't, we either have a race to
        # get/set it or have to synchronize access.
        start_node(0)
      rescue StandardError => e
        @io.close
        raise e
      end
    end

    # Return the record for the IP address in the {MaxMind
    # DB}[https://maxmind.github.io/MaxMind-DB/]. The record can be one of
    # several types and depends on the contents of the database.
    #
    # If no record is found for the IP address, +get+ returns +nil+.
    #
    # @param ip_address [String, IPAddr] IPv4 or IPv6 address.
    #
    # @raise [ArgumentError] if you attempt to look up an IPv6 address in an
    #   IPv4-only database.
    #
    # @raise [InvalidDatabaseError] if the database is corrupt or invalid.
    #
    # @return [Object, nil]
    def get(ip_address)
      record, = get_with_prefix_length(ip_address)

      record
    end

    # Return an array containing the record for the IP address in the
    # {MaxMind DB}[https://maxmind.github.io/MaxMind-DB/] and its associated
    # network prefix length. The record can be one of several types and
    # depends on the contents of the database.
    #
    # If no record is found for the IP address, the record will be +nil+ and
    # the prefix length will be the value for the missing network.
    #
    # @param ip_address [String, IPAddr] IPv4 or IPv6 address.
    #
    # @raise [ArgumentError] if you attempt to look up an IPv6 address in an
    #   IPv4-only database.
    #
    # @raise [InvalidDatabaseError] if the database is corrupt or invalid.
    #
    # @return [Array<(Object, Integer)>]
    def get_with_prefix_length(ip_address)
      ip = ip_address.is_a?(IPAddr) ? ip_address : IPAddr.new(ip_address)

      # We could check the IP has the correct prefix (32 or 128) but I do not
      # for performance reasons.

      ip_version = ip.ipv6? ? 6 : 4
      if ip_version == 6 && @ip_version == 4
        raise ArgumentError,
              "Error looking up #{ip}. You attempted to look up an IPv6 address in an IPv4-only database."
      end

      pointer, depth = find_address_in_tree(ip, ip_version)
      return nil, depth if pointer == 0

      [resolve_data_pointer(pointer), depth]
    end

    private

    IP_VERSION_TO_BIT_COUNT = {
      4 => 32,
      6 => 128,
    }.freeze
    private_constant :IP_VERSION_TO_BIT_COUNT

    def find_address_in_tree(ip_address, ip_version)
      packed = ip_address.hton

      bit_count = IP_VERSION_TO_BIT_COUNT[ip_version]
      node = start_node(bit_count)

      node_count = @node_count

      depth = 0
      loop do
        break if depth >= bit_count || node >= node_count

        c = packed[depth >> 3].ord
        bit = 1 & (c >> (7 - (depth % 8)))
        node = read_node(node, bit)
        depth += 1
      end

      return 0, depth if node == node_count

      return node, depth if node > node_count

      raise InvalidDatabaseError, 'Invalid node in search tree'
    end

    def start_node(length)
      return 0 if @ip_version != 6 || length == 128

      return @ipv4_start if @ipv4_start

      node = 0
      96.times do
        break if node >= @metadata.node_count

        node = read_node(node, 0)
      end

      @ipv4_start = node
    end

    # Read a record from the indicated node. Index indicates whether it's the
    # left (0) or right (1) record.
    def read_node(node_number, index)
      base_offset = node_number * @node_byte_size

      if @record_size == 24
        offset = index == 0 ? base_offset : base_offset + 3
        buf = @io.read(offset, 3)
        node_bytes = "\x00".b << buf
        return node_bytes.unpack1('N')
      end

      if @record_size == 28
        if index == 0
          buf = @io.read(base_offset, 4)
          n = buf.unpack1('N')
          last24 = n >> 8
          first4 = (n & 0xf0) << 20
          return first4 | last24
        end
        buf = @io.read(base_offset + 3, 4)
        return buf.unpack1('N') & 0x0fffffff
      end

      if @record_size == 32
        offset = index == 0 ? base_offset : base_offset + 4
        node_bytes = @io.read(offset, 4)
        return node_bytes.unpack1('N')
      end

      raise InvalidDatabaseError, "Unsupported record size: #{@record_size}"
    end

    def resolve_data_pointer(pointer)
      offset_in_file = pointer - @node_count + @search_tree_size

      if offset_in_file >= @size
        raise InvalidDatabaseError,
              'The MaxMind DB file\'s search tree is corrupt'
      end

      data, = @decoder.decode(offset_in_file)
      data
    end

    def find_metadata_start
      metadata_max_size = [@size, METADATA_MAX_SIZE].min

      stop_index = @size - metadata_max_size
      index = @size - METADATA_START_MARKER_LENGTH
      while index >= stop_index
        return index + METADATA_START_MARKER_LENGTH if at_metadata?(index)

        index -= 1
      end

      raise InvalidDatabaseError,
            'Metadata section not found. Is this a valid MaxMind DB file?'
    end

    def at_metadata?(index)
      @io.read(index, METADATA_START_MARKER_LENGTH) == METADATA_START_MARKER
    end

    public

    # Close the DB and return resources to the system.
    #
    # @return [void]
    def close
      @io.close
    end
  end
end
