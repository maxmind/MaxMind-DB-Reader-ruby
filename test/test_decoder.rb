# frozen_string_literal: true

require 'maxmind/db'
require 'minitest/autorun'
require 'mmdb_util'

class DecoderTest < Minitest::Test
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

  # rubocop:disable Style/ClassVars
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
  # rubocop:enable Style/ClassVars

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
    values = []
    tests.each do |input, expected|
      values << check_decoding(type, input, expected)
    end
    values
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
