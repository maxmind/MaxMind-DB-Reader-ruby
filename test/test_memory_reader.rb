# frozen_string_literal: true

require 'maxmind/db/memory_reader'
require 'minitest/autorun'

class MemoryReaderTest < Minitest::Test
  def setup
    @reader = MaxMind::DB::MemoryReader.new('abc'.b, is_buffer: true)
  end

  def test_getbyte_requires_an_existing_byte
    assert_equal('c'.ord, @reader.getbyte(2))
    assert_raises(MaxMind::DB::InvalidDatabaseError) { @reader.getbyte(3) }
  end

  def test_read_requires_the_full_range
    assert_equal('bc', @reader.read(1, 2))
    assert_equal(''.b, @reader.read(4, 0))
    assert_raises(MaxMind::DB::InvalidDatabaseError) { @reader.read(2, 2) }
    assert_raises(MaxMind::DB::InvalidDatabaseError) { @reader.read(4, 1) }
  end

  def test_read_uses_the_current_buffer_length
    buffer = 'abc'.b
    reader = MaxMind::DB::MemoryReader.new(buffer, is_buffer: true)
    buffer.replace('a'.b)

    assert_raises(MaxMind::DB::InvalidDatabaseError) { reader.read(0, 2) }
  end
end
