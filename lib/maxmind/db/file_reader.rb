require 'maxmind/db/errors'

module MaxMind # :nodoc:
  class DB
    class FileReader # :nodoc:
      def initialize(filename)
        @fh = File.new(filename, 'rb'.freeze)
        @size = @fh.size
        @mutex = Mutex.new
      end

      def size
        @size
      end

      def close
        @fh.close
      end

      def read(offset, size)
        return "".freeze.b if size == 0

        # When we support only Ruby 2.5+, remove this and require pread.
        if @fh.respond_to?(:pread)
          buf = @fh.pread(size, offset)
        else
          @mutex.synchronize do
            @fh.seek(offset, IO::SEEK_SET)
            buf = @fh.read(size)
          end
        end

        raise InvalidDatabaseError, 'The MaxMind DB file contains bad data'.freeze if buf.nil? || buf.length != size

        return buf
      end
    end
  end
end
