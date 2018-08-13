module MaxMind # :nodoc:
  class DB
    class MemoryReader # :nodoc:
      def initialize(filename, options = {})
        if options[:is_buffer]
          @buf = filename
          @size = @buf.length
          return
        end

        @buf = File.read(filename, mode: 'rb'.freeze).freeze
        @size = @buf.length
      end

      def size
        @size
      end

      def close
      end

      def read(offset, size)
        @buf[offset, size]
      end
    end
  end
end
