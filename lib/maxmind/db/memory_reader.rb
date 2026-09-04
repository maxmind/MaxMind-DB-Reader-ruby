# frozen_string_literal: true

require 'maxmind/db/errors'

module MaxMind
  class DB
    # @!visibility private
    class MemoryReader
      def initialize(filename, options = {})
        if options[:is_buffer]
          @buf = filename
          @size = @buf.length
          return
        end

        @buf = File.read(filename, mode: 'rb').freeze
        @size = @buf.length
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

        raise_bad_data if offset + size > @buf.length

        @buf.byteslice(offset, size)
      end

      private

      def raise_bad_data
        raise InvalidDatabaseError, 'The MaxMind DB file contains bad data'
      end
    end
  end
end
