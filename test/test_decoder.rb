# frozen_string_literal: true

require 'maxmind/db'
require 'minitest/autorun'
require 'mmdb_util'

class DecoderTest < Minitest::Test
  class HeaderOnlyReader
    def initialize(header)
      @header = header
    end

    def getbyte(offset)
      byte = @header.getbyte(offset)
      raise "The decoder read beyond the header at offset #{offset}" unless byte

      byte
    end

    def read(offset, size)
      bytes = @header.byteslice(offset, size)
      if bytes.nil? || bytes.bytesize != size
        message = "The decoder read #{size} payload bytes at offset #{offset}"
        raise message
      end

      bytes
    end
  end

  def test_arrays
    arrays = {
      "\x00\x04".b => [],
      "\x01\x04\x43\x46\x6f\x6f".b => ['Foo'],
      "\x02\x04\x43\x46\x6f\x6f\x43\xe4\xba\xba".b => %w[Foo 人],
    }
    validate_type_decoding('arrays', arrays)
  end

  def test_boolean
    booleans = {
      "\x00\x07".b => false,
      "\x01\x07".b => true,
    }
    validate_type_decoding('booleans', booleans)
  end

  def test_bytes
    tests = {
      "\x83\xE4\xBA\xBA".b => '人'.b,
    }
    validate_type_decoding('bytes', tests)
  end

  def test_double
    doubles = {
      "\x68\x00\x00\x00\x00\x00\x00\x00\x00".b => 0.0,
      "\x68\x3F\xE0\x00\x00\x00\x00\x00\x00".b => 0.5,
      "\x68\x40\x09\x21\xFB\x54\x44\x2E\xEA".b => 3.14159265359,
      "\x68\x40\x5E\xC0\x00\x00\x00\x00\x00".b => 123.0,
      "\x68\x41\xD0\x00\x00\x00\x07\xF8\xF4".b => 1_073_741_824.12457,
      "\x68\xBF\xE0\x00\x00\x00\x00\x00\x00".b => -0.5,
      "\x68\xC0\x09\x21\xFB\x54\x44\x2E\xEA".b => -3.14159265359,
      "\x68\xC1\xD0\x00\x00\x00\x07\xF8\xF4".b => -1_073_741_824.12457,
    }
    validate_type_decoding('double', doubles)
  end

  def test_float
    floats = {
      "\x04\x08\x00\x00\x00\x00".b => 0.0,
      "\x04\x08\x3F\x80\x00\x00".b => 1.0,
      "\x04\x08\x3F\x8C\xCC\xCD".b => 1.1,
      "\x04\x08\x40\x48\xF5\xC3".b => 3.14,
      "\x04\x08\x46\x1C\x3F\xF6".b => 9999.99,
      "\x04\x08\xBF\x80\x00\x00".b => -1.0,
      "\x04\x08\xBF\x8C\xCC\xCD".b => -1.1,
      "\x04\x08\xC0\x48\xF5\xC3".b => -3.14,
      "\x04\x08\xC6\x1C\x3F\xF6".b => -9999.99
    }
    validate_type_decoding('float', floats)
  end

  def test_int32
    int32 = {
      "\x00\x01".b => 0,
      "\x04\x01\xff\xff\xff\xff".b => -1,
      "\x01\x01\xff".b => 255,
      "\x04\x01\xff\xff\xff\x01".b => -255,
      "\x02\x01\x01\xf4".b => 500,
      "\x04\x01\xff\xff\xfe\x0c".b => -500,
      "\x02\x01\xff\xff".b => 65_535,
      "\x04\x01\xff\xff\x00\x01".b => -65_535,
      "\x03\x01\xff\xff\xff".b => 16_777_215,
      "\x04\x01\xff\x00\x00\x01".b => -16_777_215,
      "\x04\x01\x7f\xff\xff\xff".b => 2_147_483_647,
      "\x04\x01\x80\x00\x00\x01".b => -2_147_483_647,
    }
    validate_type_decoding('int32', int32)
  end

  def test_map
    maps = {
      "\xe0".b => {},
      "\xe1\x42\x65\x6e\x43\x46\x6f\x6f".b => {
        'en' => 'Foo'
      },
      "\xe2\x42\x65\x6e\x43\x46\x6f\x6f\x42\x7a\x68\x43\xe4\xba\xba".b => {
        'en' => 'Foo',
        'zh' => '人'
      },
      "\xe1\x44\x6e\x61\x6d\x65\xe2\x42\x65\x6e".b +
      "\x43\x46\x6f\x6f\x42\x7a\x68\x43\xe4\xba\xba".b => {
        'name' => {
          'en' => 'Foo',
          'zh' => '人'
        }
      },
      "\xe1\x49\x6c\x61\x6e\x67\x75\x61\x67\x65\x73".b +
      "\x02\x04\x42\x65\x6e\x42\x7a\x68".b => {
        'languages' => %w[en zh]
      },
      MMDBUtil.make_metadata_map(28) => {
        'node_count' => 0,
        'record_size' => 28,
        'ip_version' => 4,
        'database_type' => 'test',
        'languages' => ['en'],
        'binary_format_major_version' => 2,
        'binary_format_minor_version' => 0,
        'build_epoch' => 0,
        'description' => 'hi',
      },
    }
    validate_type_decoding('maps', maps)
  end

  def test_pointer
    pointers = {
      "\x20\x00".b => 0,
      "\x20\x05".b => 5,
      "\x20\x0a".b => 10,
      "\x23\xff".b => 1023,
      "\x28\x03\xc9".b => 3017,
      "\x2f\xf7\xfb".b => 524_283,
      "\x2f\xff\xff".b => 526_335,
      "\x37\xf7\xf7\xfe".b => 134_217_726,
      "\x37\xff\xff\xff".b => 134_744_063,
      "\x38\x7f\xff\xff\xff".b => 2_147_483_647,
      "\x38\xff\xff\xff\xff".b => 4_294_967_295,
    }
    validate_type_decoding('pointers', pointers)
  end

  def encode_pointer1(target)
    # One-byte-payload pointer (type 1, pointer_size 0) with base 0.
    [(1 << 5) | ((target >> 8) & 0x7), target & 0xFF].pack('C*').b
  end

  def test_pointer_fan_out_is_bounded
    # A data section of nested arrays, each holding two pointers to the node
    # below, would cost 2**depth decode operations. The decoder bounds the
    # number of values it decodes per lookup and rejects the database.
    depth = 100
    buf = "\xa0".b # leaf: uint16 with value 0
    prev = 0
    depth.times do
      offset = buf.bytesize
      buf += "\x02\x04".b + encode_pointer1(prev) + encode_pointer1(prev)
      prev = offset
    end

    io = MaxMind::DB::MemoryReader.new(buf, is_buffer: true)
    assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0).decode(prev)
    end
  end

  def scalar_pointer_array(pointer_count)
    # A uint16 leaf at offset 0 and, at offset 1, an array of pointers to it.
    array_header = [0x1e, 4, pointer_count - 285].pack('CCn')
    array = array_header + (encode_pointer1(0) * pointer_count)
    MaxMind::DB::MemoryReader.new("\xa0".b + array, is_buffer: true)
  end

  def test_value_limit_follows_the_flat_rule
    # The specification charges the root as one value and each pointer as the
    # value it resolves to, not as a separate value. An array of 65,535
    # pointers to a scalar is therefore 65,536 values, exactly the limit, and
    # decodes. One more pointer exceeds it.
    decoded, = MaxMind::DB::Decoder.new(scalar_pointer_array(65_535), 0).decode(1)

    assert_equal(65_535, decoded.length)

    error = assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(scalar_pointer_array(65_536), 0).decode(1)
    end
    assert_equal(
      'The MaxMind DB file\'s data section exceeds the maximum number of values',
      error.message
    )
  end

  def test_integer_payload_is_charged
    # A variable-length integer charges its declared size against the payload
    # budget like a string does. A 4-byte uint32 decodes with a 4-byte budget
    # and is rejected with a 3-byte one; a 16-byte uint128 likewise at 16 and
    # 15. 0xc4 is uint32 with size 4; 0x10 0x03 is the extended uint128 type
    # with size 16.
    message = 'The MaxMind DB file\'s data section exceeds the maximum number of bytes'
    uint32 = MaxMind::DB::MemoryReader.new("\xc4\x00\x00\x00\x01".b, is_buffer: true)
    uint128 = MaxMind::DB::MemoryReader.new(
      "\x10\x03".b + ("\x00".b * 15) + "\x01".b, is_buffer: true
    )

    assert_equal(1, MaxMind::DB::Decoder.new(uint32, 0, max_payload_bytes: 4).decode(0)[0])
    assert_equal(1, MaxMind::DB::Decoder.new(uint128, 0, max_payload_bytes: 16).decode(0)[0])

    [[uint32, 3], [uint128, 15]].each do |io, limit|
      error = assert_raises(MaxMind::DB::InvalidDatabaseError, limit.to_s) do
        MaxMind::DB::Decoder.new(io, 0, max_payload_bytes: limit).decode(0)
      end
      assert_equal(message, error.message)
    end
  end

  def test_unknown_type_raises
    # An extended type byte selects type 7 + its value. 0x10 gives type 23,
    # which the format does not define; the deprecated end marker is type 13.
    # Both must raise InvalidDatabaseError rather than fail inside the dispatch.
    ["\x00\x10".b, "\x00\x06".b].each do |buf|
      io = MaxMind::DB::MemoryReader.new(buf, is_buffer: true)
      error = assert_raises(MaxMind::DB::InvalidDatabaseError, buf.inspect) do
        MaxMind::DB::Decoder.new(io, 0).decode(0)
      end
      assert_match(/unknown data type/, error.message)
    end
  end

  def test_pointer_to_pointer_raises
    # The specification forbids a pointer from targeting another pointer.
    io = MaxMind::DB::MemoryReader.new("\x20\x02\x20\x02".b, is_buffer: true)
    error = assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0).decode(0)
    end
    assert_equal(
      'The MaxMind DB file\'s data section contains bad data (pointer points to another pointer)',
      error.message
    )
  end

  def test_cyclic_pointer_raises
    # An array that contains a pointer back to itself is a legal pointer target
    # but must still be stopped by the depth limit.
    io = MaxMind::DB::MemoryReader.new("\x01\x04\x20\x00".b, is_buffer: true)
    assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0).decode(0)
    end
  end

  def test_depth_limit_boundary
    # A shallow explicit limit tests the boundary without depending on the
    # native stack available to a particular Ruby implementation.
    limit = 32
    io = MaxMind::DB::MemoryReader.new(("\x01\x04".b * limit) + "\xa0".b, is_buffer: true)
    decoded, = MaxMind::DB::Decoder.new(io, 0, max_depth: limit).decode(0)
    limit.times { decoded = decoded.fetch(0) }

    assert_equal(0, decoded)

    io = MaxMind::DB::MemoryReader.new(
      ("\x01\x04".b * (limit + 1)) + "\xa0".b,
      is_buffer: true
    )
    error = assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0, max_depth: limit).decode(0)
    end
    assert_equal(
      'The MaxMind DB file\'s data section exceeds the maximum depth',
      error.message
    )
  end

  def test_container_depth_is_restored_between_siblings
    count = 600
    array_header = [0x1e, 4, count - 285].pack('CCn')
    containers = {
      'arrays' => "\x00\x04".b,
      'maps' => "\xe0".b,
    }

    containers.each do |name, empty_container|
      io = MaxMind::DB::MemoryReader.new(
        array_header + (empty_container * count),
        is_buffer: true
      )
      decoded, = MaxMind::DB::Decoder.new(io, 0).decode(0)

      assert_equal(count, decoded.length, name)
      assert_empty(decoded.reject(&:empty?), name)
    end
  end

  def test_oversized_payload_is_rejected_before_read
    # Each header declares a two-byte payload, but the reader contains only the
    # header and raises if the decoder tries to copy the missing payload.
    headers = {
      'UTF-8 string' => "\x42".b,
      'bytes' => "\x82".b,
    }

    headers.each do |name, header|
      io = HeaderOnlyReader.new(header)
      error = assert_raises(MaxMind::DB::InvalidDatabaseError, name) do
        MaxMind::DB::Decoder.new(io, 0, max_payload_bytes: 1).decode(0)
      end
      assert_equal(
        'The MaxMind DB file\'s data section exceeds the maximum number of bytes',
        error.message,
        name
      )
    end
  end

  def test_oversized_array_is_bounded
    # An array that declares 65,536 children contains 65,537 total values with
    # the array itself, so it exceeds the 65,536-value limit. The reader holds
    # only the header and raises if the decoder tries to read a child. 0x1e 0x04
    # selects an array with size code 30; 0xfee3 encodes 65,536 - 285.
    io = HeaderOnlyReader.new("\x1e\x04\xfe\xe3".b)
    error = assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0).decode(0)
    end
    assert_equal(
      'The MaxMind DB file\'s data section exceeds the maximum number of values',
      error.message
    )
  end

  def test_oversized_map_is_bounded
    # A map entry decodes a key and a value, so a map of N entries costs 2N
    # children. A map that declares 32,769 entries has 65,538 children and
    # 65,539 total values including the map itself, just past the 65,536 limit,
    # and is rejected before any entry is read. 0xfe is a map with size code
    # 30, then the two size bytes for 32,769 - 285 = 32,484 (0x7ee4).
    io = MaxMind::DB::MemoryReader.new("\xfe\x7e\xe4".b, is_buffer: true)
    assert_raises(MaxMind::DB::InvalidDatabaseError) do
      MaxMind::DB::Decoder.new(io, 0).decode(0)
    end
  end

  # rubocop:disable-next Style/ClassVars
  @@strings = {
    "\x40".b => '',
    "\x41\x31".b => '1',
    "\x43\xE4\xBA\xBA".b => '人',
    "\x5b\x31\x32\x33\x34".b +
    "\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35".b +
    "\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35\x36\x37".b =>
    '123456789012345678901234567',
    "\x5c\x31\x32\x33\x34".b +
    "\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35".b +
    "\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35\x36".b +
    "\x37\x38".b => '1234567890123456789012345678',
    "\x5d\x00\x31\x32\x33".b +
    "\x34\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34".b +
    "\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35".b +
    "\x36\x37\x38\x39".b => '12345678901234567890123456789',
    "\x5d\x01\x31\x32\x33".b +
    "\x34\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34".b +
    "\x35\x36\x37\x38\x39\x30\x31\x32\x33\x34\x35".b +
    "\x36\x37\x38\x39\x30".b => '123456789012345678901234567890',
    "\x5e\x00\xd7".b + ("\x78".b * 500) => 'x' * 500,
    "\x5e\x06\xb3".b + ("\x78".b * 2000) => 'x' * 2000,
    "\x5f\x00\x10\x53".b + ("\x78".b * 70_000) => 'x' * 70_000,
  }

  def test_string
    values = validate_type_decoding('string', @@strings)

    values.each do |s|
      assert_equal(Encoding::UTF_8, s.encoding)
    end
  end

  def test_uint16
    uint16 = {
      "\xa0".b => 0,
      "\xa1\xff".b => 255,
      "\xa2\x01\xf4".b => 500,
      "\xa2\x2a\x78".b => 10_872,
      "\xa2\xff\xff".b => 65_535,
    }
    validate_type_decoding('uint16', uint16)
  end

  def test_uint32
    uint32 = {
      "\xc0".b => 0,
      "\xc1\xff".b => 255,
      "\xc2\x01\xf4".b => 500,
      "\xc2\x2a\x78".b => 10_872,
      "\xc2\xff\xff".b => 65_535,
      "\xc3\xff\xff\xff".b => 16_777_215,
      "\xc4\xff\xff\xff\xff".b => 4_294_967_295,
    }
    validate_type_decoding('uint32', uint32)
  end

  def generate_large_uint(bits)
    ctrl_byte = bits == 64 ? "\x02".b : "\x03".b
    uints = {
      "\x00".b + ctrl_byte => 0,
      "\x02".b + ctrl_byte + "\x01\xf4".b => 500,
      "\x02".b + ctrl_byte + "\x2a\x78".b => 10_872,
    }
    ((bits / 8) + 1).times do |power|
      expected = (2**(8 * power)) - 1
      input = [power].pack('C') + ctrl_byte + ("\xff".b * power)
      uints[input] = expected
    end
    uints
  end

  def test_uint64
    validate_type_decoding('uint64', generate_large_uint(64))
  end

  def test_uint128
    validate_type_decoding('uint128', generate_large_uint(128))
  end

  def validate_type_decoding(type, tests)
    tests.map do |input, expected|
      check_decoding(type, input, expected)
    end
  end

  def check_decoding(type, input, expected, name = nil)
    name ||= expected

    io = MaxMind::DB::MemoryReader.new(input, is_buffer: true)

    pointer_base = 0
    pointer_test = true
    decoder = MaxMind::DB::Decoder.new(io, pointer_base,
                                       pointer_test)

    offset = 0
    r = decoder.decode(offset)

    if %w[float double].include?(type)
      assert_in_delta(expected, r[0], 0.001, name)
    else
      assert_equal(expected, r[0], name)
    end

    io.close
    r[0]
  end
end
