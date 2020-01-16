# frozen_string_literal: true

class MMDBUtil
  def self.make_metadata_map(record_size)
    # Map
    "\xe9".b +
      # node_count => 0
      "\x4anode_count\xc0".b +
      # record_size => 28 would be \xa1\x1c
      "\x4brecord_size\xa1".b + record_size.chr.b +
      # ip_version => 4
      "\x4aip_version\xa1\x04".b +
      # database_type => 'test'
      "\x4ddatabase_type\x44test".b +
      # languages => ['en']
      "\x49languages\x01\x04\x42en".b +
      # binary_format_major_version => 2
      "\x5bbinary_format_major_version\xa1\x02".b +
      # binary_format_minor_version => 0
      "\x5bbinary_format_minor_version\xa0".b +
      # build_epoch => 0
      "\x4bbuild_epoch\x00\x02".b +
      # description => 'hi'
      "\x4bdescription\x42hi".b
  end
end
