# frozen_string_literal: true

require 'find'
require 'minitest/autorun'

class TestLiteralsFrozen < Minitest::Test # :nodoc:
  def test_all_files
    Find.find('lib/', 'test/') do |path|
      next unless path.end_with?('.rb')

      File.open(path, 'r') do |file|
        found = false

        5.times do
          break unless (line = file.gets)

          line = line.chomp

          if line == '# frozen_string_literal: true'
            found = true
            break
          end
        end

        assert_equal(true, found, "found frozen_string_literal magic comment in #{path}")
      end
    end
  end
end
