require 'maxmind/db/errors'

module MaxMind # :nodoc:
  class DB
    # +Decoder+ decodes a {MaxMind DB}[http://maxmind.github.io/MaxMind-DB/]
    # data section.
    #
    # Typically you will interact with this class through a Reader rather than
    # directly.
    class Decoder # :nodoc:
      # Create a +Decoder+.
      #
      # +io+ is the DB. It must provide a +read+ method. It must be opened in
      # binary mode.
      #
      # +pointer_base+ is the base number to use when decoding a pointer. It is
      # where the data section begins rather than the beginning of the file.
      # The specification states the formula in the `Data Section Separator'
      # section.
      #
      # +pointer_test+ is used for testing pointer code.
      def initialize(io, pointer_base=0, pointer_test=false)
        @io = io
        @pointer_base = pointer_base
        @pointer_test = pointer_test
      end

      private

      def decode_array(size, offset)
        array = []
        size.times do
          value, offset = decode(offset)
          array << value
        end
        return array, offset
      end

      def decode_boolean(size, offset)
        return size != 0, offset
      end

      def decode_bytes(size, offset)
        return @io.read(offset, size), offset + size
      end

      def decode_double(size, offset)
        verify_size(8, size)
        buf = @io.read(offset, 8)
        return buf.unpack('G'.freeze)[0], offset + 8
      end

      def decode_float(size, offset)
        verify_size(4, size)
        buf = @io.read(offset, 4)
        return buf.unpack('g'.freeze)[0], offset + 4
      end

      def verify_size(expected, actual)
        if expected != actual
          raise InvalidDatabaseError,
            'The MaxMind DB file\'s data section contains bad data (unknown data type or corrupt data)'.freeze
        end
      end

      def decode_int32(size, offset)
        decode_int('l>'.freeze, 4, size, offset)
      end

      def decode_uint16(size, offset)
        decode_int('n'.freeze, 2, size, offset)
      end

      def decode_uint32(size, offset)
        decode_int('N'.freeze, 4, size, offset)
      end

      def decode_uint64(size, offset)
        decode_int('Q>'.freeze, 8, size, offset)
      end

      def decode_int(type_code, type_size, size, offset)
        return 0, offset if size == 0

        buf = @io.read(offset, size)
        buf = buf.rjust(type_size, "\x00".freeze) if size != type_size
        return buf.unpack(type_code)[0], offset + size
      end

      def decode_uint128(size, offset)
        return 0, offset if size == 0

        buf = @io.read(offset, size)

        if size <= 8
          buf = buf.rjust(8, "\x00".freeze)
          return buf.unpack('Q>'.freeze)[0], offset + size
        end

        a_bytes = buf[0...-8].rjust(8, "\x00".freeze)
        b_bytes = buf[-8...buf.length]
        a = a_bytes.unpack('Q>'.freeze)[0]
        b = b_bytes.unpack('Q>'.freeze)[0]
        a <<= 64
        return a | b, offset + size
      end

      def decode_map(size, offset)
        container = {}
        size.times do
          key, offset = decode(offset)
          value, offset = decode(offset)
          container[key] = value
        end
        return container, offset
      end

      def decode_pointer(size, offset)
        pointer_size = size >> 3

        if pointer_size == 0
          new_offset = offset + 1
          buf = (size & 0x7).chr << @io.read(offset, 1)
          pointer = buf.unpack('n'.freeze)[0] + @pointer_base
        elsif pointer_size == 1
          new_offset = offset + 2
          buf = "\x00".freeze.b << (size & 0x7).chr << @io.read(offset, 2)
          pointer = buf.unpack('N'.freeze)[0] + 2048 + @pointer_base
        elsif pointer_size == 2
          new_offset = offset + 3
          buf = (size & 0x7).chr << @io.read(offset, 3)
          pointer = buf.unpack('N'.freeze)[0] + 526336 + @pointer_base
        else
          new_offset = offset + 4
          buf = @io.read(offset, 4)
          pointer = buf.unpack('N'.freeze)[0] + @pointer_base
        end

        return pointer, new_offset if @pointer_test

        value, _ = decode(pointer)
        return value, new_offset
      end

      def decode_utf8_string(size, offset)
        new_offset = offset + size
        buf = @io.read(offset, size)
        buf.force_encoding(Encoding::UTF_8)
        # We could check it's valid UTF-8 with `valid_encoding?', but for
        # performance I do not.
        return buf, new_offset
      end

      TYPE_DECODER = {
        1  => :decode_pointer,
        2  => :decode_utf8_string,
        3  => :decode_double,
        4  => :decode_bytes,
        5  => :decode_uint16,
        6  => :decode_uint32,
        7  => :decode_map,
        8  => :decode_int32,
        9  => :decode_uint64,
        10 => :decode_uint128,
        11 => :decode_array,
        14 => :decode_boolean,
        15 => :decode_float,
      }.freeze
      private_constant :TYPE_DECODER

      public

      # Decode a section of the data section starting at +offset+.
      #
      # +offset+ is the location of the data structure to decode.
      #
      # Returns an array where the first element is the decoded value and the
      # second is the offset after decoding it.
      #
      # Throws an exception if there is an error.
      def decode(offset)
        new_offset = offset + 1
        buf = @io.read(offset, 1)
        ctrl_byte = buf.ord
        type_num = ctrl_byte >> 5
        type_num, new_offset = read_extended(new_offset) if type_num == 0

        size, new_offset = size_from_ctrl_byte(ctrl_byte, new_offset, type_num)
        # We could check an element exists at `type_num', but for performance I
        # don't.
        return send(TYPE_DECODER[type_num], size, new_offset)
      end

      private

      def read_extended(offset)
        buf = @io.read(offset, 1)
        next_byte = buf.ord
        type_num = next_byte + 7
        if type_num < 7
          raise InvalidDatabaseError,
            "Something went horribly wrong in the decoder. An extended type resolved to a type number < 8 (#{type_num})"
        end
        return type_num, offset + 1
      end

      def size_from_ctrl_byte(ctrl_byte, offset, type_num)
        size = ctrl_byte & 0x1f

        return size, offset if type_num == 1

        return size, offset if size < 29

        if size == 29
          size_bytes = @io.read(offset, 1)
          size = 29 + size_bytes.ord
          return size, offset + 1
        end

        if size == 30
          size_bytes = @io.read(offset, 2)
          size = 285 + size_bytes.unpack('n'.freeze)[0]
          return size, offset + 2
        end

        size_bytes = "\x00".freeze.b << @io.read(offset, 3)
        size = 65821 + size_bytes.unpack('N'.freeze)[0]
        return size, offset + 3
      end
    end
  end
end
