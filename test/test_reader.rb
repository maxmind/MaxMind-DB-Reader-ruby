require 'maxmind/db'
require 'minitest/autorun'
require 'mmdb_util'

class ReaderTest < Minitest::Test # :nodoc:
  def test_reader
    modes = [
      MaxMind::DB::MODE_FILE,
      MaxMind::DB::MODE_MEMORY,
    ]

    modes.each do |mode|
      [24, 28, 32].each do |record_size|
        [4, 6].each do |ip_version|
          filename = 'test/data/test-data/MaxMind-DB-test-ipv' +
            ip_version.to_s + '-' + record_size.to_s + '.mmdb'
          reader = MaxMind::DB.new(filename, mode: mode)
          check_metadata(reader, ip_version, record_size)
          if ip_version == 4
            check_ipv4(reader, filename)
          else
            check_ipv6(reader, filename)
          end
          reader.close
        end
      end
    end
  end

  def test_decoder
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    record = reader.get('::1.1.1.0')
    assert_equal([1, 2, 3], record['array'])
    assert_equal(true, record['boolean'])
    assert_equal("\x00\x00\x00*".b, record['bytes'])
    assert_equal(42.123456, record['double'])
    assert_in_delta(1.1, record['float'])
    assert_equal(-268435456, record['int32'])
    assert_equal(
      {
        'mapX' => {
          'arrayX'       => [7, 8, 9],
          'utf8_stringX' => 'hello',
        },
      },
      record['map'],
    )
    assert_equal(100, record['uint16'])
    assert_equal(268435456, record['uint32'])
    assert_equal(1152921504606846976, record['uint64'])
    assert_equal('unicode! ☯ - ♫', record['utf8_string'])
    assert_equal(1329227995784915872903807060280344576, record['uint128'])
    reader.close
  end

  def test_no_ipv4_search_tree
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-no-ipv4-search-tree.mmdb')
    assert_equal('::0/64', reader.get('1.1.1.1'))
    assert_equal('::0/64', reader.get('192.1.1.1'))
    reader.close
  end

  def test_ipv6_address_in_ipv4_database
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-ipv4-24.mmdb')
    e = assert_raises ArgumentError do
      reader.get('2001::')
    end
    assert_equal(
      'Error looking up 2001::. You attempted to look up an IPv6 address in an IPv4-only database.',
      e.message,
    )
    reader.close
  end

  def test_bad_ip_parameter
    reader = MaxMind::DB.new('test/data/test-data/GeoIP2-City-Test.mmdb')
    e = assert_raises ArgumentError do
      reader.get(Object.new)
    end
    assert_equal(
      'address family must be specified', # Not great, but type is ok
      e.message,
    )
    reader.close
  end

  def test_broken_database
    reader = MaxMind::DB.new(
      'test/data/test-data/GeoIP2-City-Test-Broken-Double-Format.mmdb')
    e = assert_raises MaxMind::DB::InvalidDatabaseError do
      reader.get('2001:220::')
    end
    assert_equal(
      'The MaxMind DB file\'s data section contains bad data (unknown data type or corrupt data)',
      e.message,
    )
    reader.close
  end

  def test_ip_validation
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    e = assert_raises ArgumentError do
      reader.get('not_ip')
    end
    assert_equal('invalid address', e.message)
    reader.close
  end

  def test_missing_database
    e = assert_raises SystemCallError do
      MaxMind::DB.new('file-does-not-exist.mmdb')
    end
    assert(e.message.match(/No such file or directory/))
  end

  def test_nondatabase
    e = assert_raises MaxMind::DB::InvalidDatabaseError do
      MaxMind::DB.new('README.md')
    end
    assert_equal(
      'Metadata section not found. Is this a valid MaxMind DB file?',
      e.message,
    )
  end

  def test_too_many_constructor_args
    e = assert_raises ArgumentError do
      MaxMind::DB.new('README.md', {}, 'blah')
    end
    assert(e.message.match(/wrong number of arguments/))
  end

  def test_no_constructor_args
    e = assert_raises ArgumentError do
      MaxMind::DB.new
    end
    assert(e.message.match(/wrong number of arguments/))
  end

  def test_too_many_get_args
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    e = assert_raises ArgumentError do
      reader.get('1.1.1.1', 'blah')
    end
    assert(e.message.match(/wrong number of arguments/))
    reader.close
  end

  def test_no_get_args
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    e = assert_raises ArgumentError do
      reader.get
    end
    assert(e.message.match(/wrong number of arguments/))
    reader.close
  end

  def test_metadata_args
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    e = assert_raises ArgumentError do
      reader.metadata('hi')
    end
    assert(e.message.match(/wrong number of arguments/))
    reader.close
  end

  def test_metadata_unknown_attribute
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    e = assert_raises NoMethodError do
      reader.metadata.what
    end
    assert(e.message.match(/undefined method `what'/))
    reader.close
  end

  def test_close
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    reader.close
  end

  def test_double_close
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    reader.close
    reader.close
  end

  def test_closed_get
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    reader.close
    e = assert_raises IOError do
      reader.get('1.1.1.1')
    end
    assert_equal('closed stream', e.message)
  end

  def test_closed_metadata
    reader = MaxMind::DB.new(
      'test/data/test-data/MaxMind-DB-test-decoder.mmdb')
    reader.close
    assert_equal(
      {"en"=>"MaxMind DB Decoder Test database - contains every MaxMind DB data type"},
      reader.metadata.description,
    )
  end

  def test_threads
    reader = MaxMind::DB.new(
      'test/data/test-data/GeoIP2-Domain-Test.mmdb')

    num_threads = 16
    num_lookups = 32
    thread_lookups = []
    num_threads.times do
      thread_lookups << []
    end

    threads = []
    num_threads.times do |i|
      threads << Thread.new do
        num_lookups.times do |j|
          thread_lookups[i] << reader.get("65.115.240.#{j}")
          thread_lookups[i] << reader.get("2a02:2770:3::#{j}")
        end
      end
    end

    threads.each do |thread|
      thread.join
    end

    thread_lookups.each do |a|
      assert_equal(num_lookups * 2, a.length)
      thread_lookups.each do |b|
        assert_equal(a, b)
      end
    end

    reader.close
  end

  # In these tests I am trying to exercise Reader#read_node directly. It is not
  # too easy to test its behaviour with real databases, so construct dummy ones
  # directly.
  def test_read_node
    tests = [
      {
        record_size: 24,
        # Left record + right record
        node_bytes:  "\xab\xcd\xef".b + "\xbc\xfe\xfa".b,
        left:        11259375,
        right:       12386042,
        check_left:  "\x00\xab\xcd\xef".b.unpack('N')[0],
        check_right: "\x00\xbc\xfe\xfa".b.unpack('N')[0],
      },
      {
        record_size: 28,
        # Left record (part) + middle byte + right record (part)
        node_bytes:  "\xab\xcd\xef".b + "\x12".b + "\xfd\xdc\xfa".b,
        left:        28036591,
        right:       50191610,
        check_left:  "\x01\xab\xcd\xef".b.unpack('N')[0],
        check_right: "\x02\xfd\xdc\xfa".b.unpack('N')[0],
      },
      {
        record_size: 32,
        # Left record + right record
        node_bytes:  "\xab\xcd\xef\x12".b + "\xfd\xdc\xfa\x15".b,
        left:        2882400018,
        right:       4259117589,
        check_left:  "\xab\xcd\xef\x12".b.unpack('N')[0],
        check_right: "\xfd\xdc\xfa\x15".b.unpack('N')[0],
      },
    ]

    tests.each do |test|
      buf = "".b
      buf += test[:node_bytes]

      buf += "\x00".b * 16

      buf += "\xab\xcd\xefMaxMind.com".b
      buf += MMDBUtil.make_metadata_map(test[:record_size])

      reader = MaxMind::DB.new(
        buf, mode: MaxMind::DB::MODE_PARAM_IS_BUFFER)

      assert_equal(reader.metadata.record_size, test[:record_size])

      assert_equal(test[:left],  reader.send(:read_node, 0, 0))
      assert_equal(test[:right], reader.send(:read_node, 0, 1))
      assert_equal(test[:left],  test[:check_left])
      assert_equal(test[:right], test[:check_right])
    end
  end

  def check_metadata(reader, ip_version, record_size)
    metadata = reader.metadata

    assert_equal(2, metadata.binary_format_major_version, 'major_version')
    assert_equal(0, metadata.binary_format_minor_version, 'minor_version')
    assert_operator(metadata.build_epoch, :>, 1373571901, 'build_epoch')
    assert_equal('Test', metadata.database_type, 'database_type')
    assert_equal(
      {
        'en' => 'Test Database',
        'zh' => 'Test Database Chinese',
      },
      metadata.description,
      'description',
    )
    assert_equal(ip_version, metadata.ip_version, 'ip_version')
    assert_equal(['en', 'zh'], metadata.languages, 'languages')
    assert_operator(metadata.node_count, :>, 36, 'node_count')
    assert_equal(record_size, metadata.record_size, 'record_size')
  end

  def check_ipv4(reader, filename)
    6.times do |i|
      address = "1.1.1.#{2**i}"
      assert_equal(
        { 'ip' => address },
        reader.get(address),
        "found expected data record for #{address} in #{filename}",
      )
    end

    pairs = {
      '1.1.1.3'  => '1.1.1.2',
      '1.1.1.5'  => '1.1.1.4',
      '1.1.1.7'  => '1.1.1.4',
      '1.1.1.9'  => '1.1.1.8',
      '1.1.1.15' => '1.1.1.8',
      '1.1.1.17' => '1.1.1.16',
      '1.1.1.31' => '1.1.1.16',
    }
    pairs.each do |key_address, value_address|
      data = {'ip' => value_address}
      assert_equal(
        data,
        reader.get(key_address),
        "found expected data record for #{key_address} in #{filename}",
      )
    end

    ['1.1.1.33', '255.254.253.123'].each do |ip|
      assert_nil(
        reader.get(ip),
        "#{ip} is not in #{filename}",
      )
    end
  end

  def check_ipv6(reader, filename)
    subnets = [
      '::1:ffff:ffff', '::2:0:0', '::2:0:40', '::2:0:50', '::2:0:58',
    ]
    subnets.each do |address|
      assert_equal(
        {'ip' => address },
        reader.get(address),
        "found expected data record for #{address} in #{filename}",
      )
    end

    pairs = {
      '::2:0:1'  => '::2:0:0',
      '::2:0:33' => '::2:0:0',
      '::2:0:39' => '::2:0:0',
      '::2:0:41' => '::2:0:40',
      '::2:0:49' => '::2:0:40',
      '::2:0:52' => '::2:0:50',
      '::2:0:57' => '::2:0:50',
      '::2:0:59' => '::2:0:58',
    }
    pairs.each do |key_address, value_address|
      assert_equal(
        { 'ip' => value_address },
        reader.get(key_address),
        "found expected data record for #{key_address} in #{filename}",
      )
    end

    ['1.1.1.33', '255.254.253.123', '89fa::'].each do |ip|
      assert_nil(
        reader.get(ip),
        "#{ip} is not in #{filename}",
      )
    end
  end
end
