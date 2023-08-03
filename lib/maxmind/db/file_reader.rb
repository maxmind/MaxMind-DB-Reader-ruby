# frozen_string_literal: true

require 'maxmind/db/errors'

module MaxMind
  class DB
    # @!visibility private
    class FileReader
      if ::File.method_defined?(:pread)
        PReadFile = ::File
      else
        # For Windows support
        class PReadFile
          def initialize(filename, mode)
            @mutex = Mutex.new
            @file = File.new(filename, mode)
          end

          def size
            @file.size
          end

          def close
            @file.close
          end

          def pread(size, offset)
            @mutex.synchronize do
              @file.seek(offset, IO::SEEK_SET)
              @file.read(size)
            end
          end
        end
      end

      def initialize(filename)
        @fh = PReadFile.new(filename, 'rb')
        @size = @fh.size
      end

      attr_reader :size

      def close
        @fh.close
      end

      def read(offset, size)
        return ''.b if size == 0

        buf = @fh.pread(size, offset)

        raise InvalidDatabaseError, 'The MaxMind DB file contains bad data' if buf.nil? || buf.length != size

        buf
      end
    end
  end
end
