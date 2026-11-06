# frozen_string_literal: true

require 'maxmind/db/errors'

module MaxMind
  class DB
    # +Decoder+ decodes a {MaxMind DB}[https://maxmind.github.io/MaxMind-DB/]
    # data section.
    #
    # Typically you will interact with this class through a Reader rather than
    # directly.
    #
    # @!visibility private
    class Decoder
      # rubocop:disable Style/OptionalBooleanParameter, Metrics/ParameterLists

      # Create a +Decoder+.
      #
      # +io+ is the DB. It must provide +read+ and +getbyte+ methods. It must be
      # opened in binary mode.
      #
      # +pointer_base+ is the base number to use when decoding a pointer. It is
      # where the data section begins rather than the beginning of the file.
      # The specification states the formula in the `Data Section Separator'
      # section.
      #
      # +pointer_test+ is used for testing pointer code.
      #
      # +max_values+, +max_payload_bytes+, and +max_depth+ set the per-decode
      # limits described below and default to the constants there.
      def initialize(io, pointer_base = 0, pointer_test = false,
                     max_values: MAX_VALUES, max_payload_bytes: MAX_BYTES,
                     max_depth: MAX_DEPTH)
        @io = io
        @pointer_base = pointer_base
        @pointer_test = pointer_test
        @max_values = max_values
        @max_payload_bytes = max_payload_bytes
        @max_depth = max_depth
      end
      # rubocop:enable Style/OptionalBooleanParameter, Metrics/ParameterLists

      # Per-decode limits. The value and depth limits are the ones the MaxMind DB
      # specification recommends. The specification leaves the payload limit to
      # the reader, and 2 MiB matches libmaxminddb.
      #
      # The value limit stops a pointer fan-out. It follows the specification's
      # flat rule: the root is one value, each array reserves one value per
      # element, and each map reserves two values per entry before iterating. A
      # pointer is not charged separately from the logical value at the root or
      # its position in a container. A re-decoded node drains the budget, and an
      # oversized declared size is rejected before the loop reads anything. The
      # largest real records decode a few hundred values.
      #
      # The byte limit stops payload amplification: a crafted database can point
      # many times at one large string or bytes value, so a bounded value count
      # still materializes gigabytes. Each string and bytes value, and each
      # variable-length integer, subtracts its own length before it is read, so a
      # re-decoded (fanned-out) target recharges its payload and an oversized
      # declared length is rejected before any bytes are copied. Fixed-width
      # scalars are not charged.
      #
      # The depth limit stops a pointer cycle or over-deep data before the stack
      # overflows.
      MAX_VALUES = 1 << 16
      private_constant :MAX_VALUES

      MAX_BYTES = 1 << 21
      private_constant :MAX_BYTES

      MAX_DEPTH = 512
      private_constant :MAX_DEPTH

      # JRuby can exhaust the stack before the depth limit is reached and raises
      # a Java StackOverflowError, which is not a SystemStackError. Catch both so
      # a pointer cycle always becomes an InvalidDatabaseError.
      STACK_ERRORS = if defined?(JRUBY_VERSION)
                       [SystemStackError, Java::JavaLang::StackOverflowError].freeze
                     else
                       [SystemStackError].freeze
                     end
      private_constant :STACK_ERRORS

      private

      # The limit checks are inlined at each call site so containers and
      # pointers do not add a helper call. Only the raise is factored out.
      def raise_depth_exceeded
        raise InvalidDatabaseError,
              'The MaxMind DB file\'s data section exceeds the maximum depth'
      end

      def raise_values_exceeded
        raise InvalidDatabaseError,
              'The MaxMind DB file\'s data section exceeds the maximum number of values'
      end

      # Each string, bytes, and variable-length integer decoder charges its size
      # against the payload budget inline, before the bytes are read, so an
      # oversized declared length is rejected before it is copied. Ruby integers
      # are arbitrary precision, so the subtraction cannot overflow.
      def raise_bytes_exceeded
        raise InvalidDatabaseError,
              'The MaxMind DB file\'s data section exceeds the maximum number of bytes'
      end

      def decode_array(size, offset)
        raise_values_exceeded if (@values_left -= size) < 0
        raise_depth_exceeded if (@depth += 1) > @max_depth
        @offset = offset
        array = []
        size.times do
          array << decode_value
        end
        @depth -= 1
        array
      end

      def decode_bytes(size, offset)
        raise_bytes_exceeded if (@bytes_left -= size) < 0
        @offset = offset + size
        @io.read(offset, size)
      end

      def decode_double(size, offset)
        verify_size(8, size)
        @offset = offset + 8
        @io.read(offset, 8).unpack1('G')
      end

      def decode_float(size, offset)
        verify_size(4, size)
        @offset = offset + 4
        @io.read(offset, 4).unpack1('g')
      end

      def verify_size(expected, actual)
        return if expected == actual

        raise_invalid_size
      end

      def raise_invalid_size
        raise InvalidDatabaseError,
              'The MaxMind DB file\'s data section contains bad data (unknown data type or corrupt data)'
      end

      def decode_int32(size, offset)
        decode_int('l>', 4, size, offset)
      end

      def decode_uint16(size, offset)
        decode_int('n', 2, size, offset)
      end

      def decode_uint32(size, offset)
        decode_int('N', 4, size, offset)
      end

      def decode_uint64(size, offset)
        decode_int('Q>', 8, size, offset)
      end

      def decode_int(type_code, type_size, size, offset)
        raise_invalid_size if size > type_size
        @offset = offset + size
        return 0 if size == 0

        raise_bytes_exceeded if (@bytes_left -= size) < 0
        buf = @io.read(offset, size)
        buf = buf.rjust(type_size, "\x00") if size != type_size
        buf.unpack1(type_code)
      end

      def decode_uint128(size, offset)
        raise_invalid_size if size > 16
        @offset = offset + size
        return 0 if size == 0

        raise_bytes_exceeded if (@bytes_left -= size) < 0
        buf = @io.read(offset, size)

        return buf.rjust(8, "\x00").unpack1('Q>') if size <= 8

        a_bytes = buf[0...-8].rjust(8, "\x00")
        b_bytes = buf[-8...buf.length]
        a = a_bytes.unpack1('Q>')
        b = b_bytes.unpack1('Q>')
        a <<= 64
        a | b
      end

      def decode_map(size, offset)
        # A map entry decodes a key and a value, so it costs two values.
        raise_values_exceeded if (@values_left -= size * 2) < 0
        raise_depth_exceeded if (@depth += 1) > @max_depth
        @offset = offset
        container = {}
        size.times do
          key = decode_value
          container[key] = decode_value
        end
        @depth -= 1
        container
      end

      def decode_pointer(size, offset)
        pointer_size = size >> 3

        # Build the pointer with integer arithmetic to avoid temporary strings
        # when combining control bits with the payload bytes.
        case pointer_size
        when 0
          new_offset = offset + 1
          pointer = ((size & 0x7) << 8) | @io.getbyte(offset)
        when 1
          new_offset = offset + 2
          pointer = ((size & 0x7) << 16) | @io.read(offset, 2).unpack1('n')
          pointer += 2048
        when 2
          new_offset = offset + 3
          buf = @io.read(offset, 3)
          pointer = ((size & 0x7) << 24) | (buf.getbyte(0) << 16) |
                    (buf.getbyte(1) << 8) | buf.getbyte(2)
          pointer += 526_336
        else
          new_offset = offset + 4
          pointer = @io.read(offset, 4).unpack1('N')
        end
        pointer += @pointer_base
        [pointer, new_offset]
      end

      def decode_utf8_string(size, offset)
        raise_bytes_exceeded if (@bytes_left -= size) < 0
        @offset = offset + size
        buf = @io.read(offset, size)
        buf.force_encoding(Encoding::UTF_8)
        # We could check it's valid UTF-8 with `valid_encoding?', but for
        # performance I do not.
        buf
      end

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
        # Each call decodes with its own copy of the decoder. The copy holds the
        # offset and the remaining budgets, so the helpers return only the
        # value, and this decoder never changes. That keeps it safe for
        # concurrent reads.
        dup.decode_root(offset)
      end

      protected

      def decode_root(offset)
        # Bound the work per decode so a crafted database cannot exhaust CPU or
        # memory. The root value is charged here. Containers charge their
        # children. The depth limit catches a pointer cycle on MRI. JRuby can
        # exhaust the stack before the limit is reached and raises a Java
        # StackOverflowError, so catch that too and report the same error.
        @offset = offset
        @values_left = @max_values - 1
        @depth = 0
        @bytes_left = @max_payload_bytes
        value = decode_value
        [value, @offset]
      rescue *STACK_ERRORS
        raise_depth_exceeded
      end

      private

      # Decode the value at @offset and move @offset past it.
      #
      # The dispatch below is one branch per data type, so the method's
      # cyclomatic complexity is above the cop's default. It is inlined here
      # for speed and the branches are uniform.
      # rubocop:disable-next Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def decode_value
        offset = @offset
        pointer_return_offset = nil
        new_offset = offset + 1
        ctrl_byte = @io.getbyte(offset)
        type_num = ctrl_byte >> 5
        type_num, new_offset = read_extended(new_offset) if type_num == 0

        size, new_offset = size_from_ctrl_byte(ctrl_byte, new_offset, type_num)
        if type_num == 1
          pointer, pointer_return_offset = decode_pointer(size, new_offset)
          if @pointer_test
            @offset = pointer_return_offset
            return pointer
          end

          # The root or containing collection already charged the logical value
          # at the pointer's position. Following it adds depth but no separate
          # value. Its target cannot be another pointer, and decoding the target
          # still reserves container children and charges payload bytes.
          raise_depth_exceeded if (@depth += 1) > @max_depth
          new_offset = pointer + 1
          ctrl_byte = @io.getbyte(pointer)
          type_num = ctrl_byte >> 5
          if type_num == 1
            raise InvalidDatabaseError,
                  'The MaxMind DB file\'s data section contains bad data (pointer points to another pointer)'
          end
          type_num, new_offset = read_extended(new_offset) if type_num == 0
          size, new_offset = size_from_ctrl_byte(ctrl_byte, new_offset, type_num)
        end

        # Direct case dispatch avoids looking the method up in a Hash and
        # calling it with send.
        value = case type_num
                when 2 then decode_utf8_string(size, new_offset)
                when 3 then decode_double(size, new_offset)
                when 4 then decode_bytes(size, new_offset)
                when 5 then decode_uint16(size, new_offset)
                when 6 then decode_uint32(size, new_offset)
                when 7 then decode_map(size, new_offset)
                when 8 then decode_int32(size, new_offset)
                when 9 then decode_uint64(size, new_offset)
                when 10 then decode_uint128(size, new_offset)
                when 11 then decode_array(size, new_offset)
                when 14
                  @offset = new_offset
                  size != 0
                when 15 then decode_float(size, new_offset)
                else
                  raise InvalidDatabaseError,
                        "The MaxMind DB file's data section contains bad data (unknown data type #{type_num})"
                end
        return value unless pointer_return_offset

        @depth -= 1
        @offset = pointer_return_offset
        value
      end

      def read_extended(offset)
        next_byte = @io.getbyte(offset)
        type_num = next_byte + 7
        if type_num < 7
          raise InvalidDatabaseError,
                "Something went horribly wrong in the decoder. An extended type resolved to a type number < 8 (#{type_num})"
        end
        [type_num, offset + 1]
      end

      def size_from_ctrl_byte(ctrl_byte, offset, type_num)
        size = ctrl_byte & 0x1f

        return size, offset if type_num == 1 || size < 29

        if size == 29
          size = 29 + @io.getbyte(offset)
          return size, offset + 1
        end

        if size == 30
          size_bytes = @io.read(offset, 2)
          size = 285 + size_bytes.unpack1('n')
          return size, offset + 2
        end

        size_bytes = "\x00".b << @io.read(offset, 3)
        size = 65_821 + size_bytes.unpack1('N')
        [size, offset + 3]
      end
    end
  end
end
