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

      # Number of bytes read from the file when a read misses both windows.
      WINDOW_SIZE = 4096
      private_constant :WINDOW_SIZE

      JRUBY = defined?(JRUBY_VERSION) ? true : false
      private_constant :JRUBY

      def initialize(filename)
        @fh = PReadFile.new(filename, 'rb')
        @size = @fh.size
        @window = nil
        @previous_window = nil
        # JRuby has no global lock, so an unsynchronized read of @window could
        # see the new Array before its elements.
        @mutex = JRUBY ? Mutex.new : nil
      end

      attr_reader :size

      # Override to not show the windows in inspect to avoid showing them in
      # irb.
      def inspect
        "#<#{self.class.name}:0x#{object_id.to_s(16)}, @size=#{@size.inspect}>"
      end

      def close
        @fh.close
        @window = nil
        @previous_window = nil
      end

      # Return the byte at +offset+ as an Integer.
      def getbyte(offset)
        window = window_covering(offset, 1)
        window[2].getbyte(offset - window[0])
      end

      # Return +size+ bytes at +offset+ as a new String.
      #
      # The decoder reads a record in many small, mostly adjacent reads. A pread
      # for each one costs a system call, so a read that misses reads
      # WINDOW_SIZE bytes and keeps them for the reads that follow.
      def read(offset, size)
        return ''.b if size == 0

        if size > WINDOW_SIZE
          buf = @fh.pread(size, offset)
          raise_bad_data if buf.nil? || buf.bytesize != size

          return buf
        end

        window = window_covering(offset, size)
        buf = window[2].byteslice(offset - window[0], size)

        # The caller can keep the String, so it must not share the window's
        # buffer. CRuby shares it only for a slice that ends at the window
        # end. JRuby shares it for every slice.
        return buf unless JRUBY || offset + size == window[1]

        String.new(buf, capacity: size)
      end

      private

      def window_covering(offset, size)
        return @mutex.synchronize { find_or_read_window(offset, size) } if @mutex

        find_or_read_window(offset, size)
      end

      # Return a window, [start, end, bytes], that holds +size+ bytes at
      # +offset+. Two windows are kept because a data pointer often leaves a
      # map for another window, and the next read returns to the map.
      #
      # The file does not change, so a window does not go stale. Each window is
      # frozen and set in a single assignment. On CRuby, a concurrent read can
      # see either window or miss, and each result is correct.
      #
      # The range checks are inline to keep a method call off the hot path.
      # rubocop:disable-next Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def find_or_read_window(offset, size)
        window = @window
        return window if window && offset >= window[0] && offset + size <= window[1]

        previous = @previous_window
        if previous && offset >= previous[0] && offset + size <= previous[1]
          @previous_window = window
          @window = previous
          return previous
        end

        bytes = @fh.pread(WINDOW_SIZE, offset)
        raise_bad_data if bytes.nil? || bytes.bytesize < size

        @previous_window = window
        @window = [offset, offset + bytes.bytesize, bytes.freeze].freeze
      end

      def raise_bad_data
        raise InvalidDatabaseError, 'The MaxMind DB file contains bad data'
      end
    end
  end
end
