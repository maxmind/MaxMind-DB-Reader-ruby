# frozen_string_literal: true

require 'maxmind/db/errors'

module MaxMind
  class DB
    # @!visibility private
    class MemoryReader
      def initialize(filename, options = {})
        if options[:is_buffer]
          @buf = filename
          @size = @buf.bytesize
          return
        end

        @buf = File.read(filename, mode: 'rb').freeze
        @size = @buf.bytesize
      end

      attr_reader :size

      # Override to not show @buf in inspect to avoid showing it in irb.
      def inspect
        "#<#{self.class.name}:0x#{self.class.object_id.to_s(16)}, @size=#{@size.inspect}>"
      end

      def close; end

      # Return the byte at +offset+ as an Integer without allocating a String.
      def getbyte(offset)
        @buf.getbyte(offset) || raise_bad_data
      end

      def read(offset, size)
        return ''.b if size == 0

        raise_bad_data if offset + size > @buf.bytesize

        @buf.byteslice(offset, size)
      end

      def unpack1(offset, size, type_code, type_size = size)
        raise_bad_data if offset + size > @buf.bytesize

        if type_size == size
          return @buf.unpack1(type_code, offset: offset)
        elsif size == 3 && type_code == 'N'
          # Fast path for 24bit integer. Avoid read+rjust
          a, b, c = getbyte(offset), getbyte(offset + 1), getbyte(offset + 2)

          return (a << 16) + (b << 8) + c
        end

        buf = read(offset, size)
        buf = buf.rjust(type_size, "\x00") if buf.bytesize < type_size
        buf.unpack1(type_code)
      end

      private

      def raise_bad_data
        raise InvalidDatabaseError, 'The MaxMind DB file contains bad data'
      end
    end
  end
end
