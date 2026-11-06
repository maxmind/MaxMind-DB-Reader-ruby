# frozen_string_literal: true

require 'maxmind/db/file_reader'
require 'minitest/autorun'
require 'tempfile'

class FileReaderTest < Minitest::Test
  def setup
    # Larger than two 4 KiB windows, so reads can cross a window boundary.
    @data = Random.new(1).bytes(10_000)
    @file = Tempfile.new('file_reader', binmode: true)
    @file.write(@data)
    @file.flush
    @reader = MaxMind::DB::FileReader.new(@file.path)
  end

  def teardown
    @reader.close
    @file.close!
  end

  def test_read_matches_file
    rng = Random.new(2)
    2_000.times do
      size = rng.rand(0..5_000)
      offset = rng.rand(0..(@data.bytesize - size))

      assert_equal(@data.byteslice(offset, size), @reader.read(offset, size), "read(#{offset}, #{size})")
    end
  end

  def test_getbyte_matches_file
    [0, 4_095, 4_096, 9_999, 5_000, 4_095].each do |offset|
      assert_equal(@data.getbyte(offset), @reader.getbyte(offset), "getbyte(#{offset})")
    end
  end

  def test_reads_reuse_the_two_windows
    preads = 0
    fh = @reader.instance_variable_get(:@fh)
    fh.define_singleton_method(:pread) do |*args|
      preads += 1
      super(*args)
    end

    reads = [
      # The first read fills a window. The next reads in it use it.
      [[0, 1], [100, 1], [200, 50]], 1,
      # A read in a new window keeps the old one as the previous window.
      [[8_000, 10], [10, 5], [8_005, 2]], 2,
      # A third window drops the least recently used one, which is at 0. The
      # window at 8,000 is kept. 9,500 is only in that window.
      [[5_000, 10], [9_500, 1], [5_001, 1]], 3,
      [[0, 1]], 4,
    ]
    reads.each_slice(2) do |calls, expected|
      calls.each do |offset, size|
        assert_equal(@data.byteslice(offset, size), @reader.read(offset, size))
        assert_equal(@data.getbyte(offset), @reader.getbyte(offset))
      end

      assert_equal(expected, preads, calls.inspect)
    end
  end

  def test_read_returns_a_new_string
    buf = @reader.read(0, 3)
    buf.force_encoding(Encoding::UTF_8)
    buf << 'x'

    assert_equal(@data.byteslice(0, 3), @reader.read(0, 3))
    assert_equal(Encoding::BINARY, @reader.read(0, 3).encoding)
  end

  def test_read_does_not_share_the_window
    skip 'ObjectSpace.dump is CRuby only' if defined?(JRUBY_VERSION)

    require 'objspace'
    @reader.read(0, 1)
    # This slice ends at the end of the window that starts at offset 0.
    buf = @reader.read(3_000, 1_096)

    assert_equal(@data.byteslice(3_000, 1_096), buf)
    refute_includes(ObjectSpace.dump(buf), '"shared":true')
  end

  def test_concurrent_reads_match_file
    threads = Array.new(8) do |i|
      # rubocop:disable ThreadSafety/NewThread
      Thread.new do
        # rubocop:enable ThreadSafety/NewThread
        rng = Random.new(i)
        Array.new(2_000) do
          size = rng.rand(1..100)
          offset = rng.rand(0..(@data.bytesize - size))
          @reader.read(offset, size) == @data.byteslice(offset, size)
        end
      end
    end

    assert_predicate(threads.flat_map(&:value), :all?)
  end

  def test_inspect_does_not_show_the_window
    @reader.read(0, 1)

    refute_includes(@reader.inspect, 'window')
  end

  def test_read_requires_the_full_range
    assert_raises(MaxMind::DB::InvalidDatabaseError) { @reader.read(9_998, 3) }
    assert_raises(MaxMind::DB::InvalidDatabaseError) { @reader.read(5_000, 5_001) }
  end
end
