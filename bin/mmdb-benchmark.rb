#!/usr/bin/env ruby

require 'maxmind/db'

def main
  args = get_args
  if args.nil?
    return false
  end

  reader = MaxMind::DB.new(args[:database], mode: MaxMind::DB::MODE_MEMORY)
  benchmark(reader, args[:ip_file])
  return true
end

def get_args
  if ARGV.length != 2
    print_usage
    return nil
  end

  database = ARGV[0]
  ip_file  = ARGV[1]

  return {
    database: database,
    ip_file:  ip_file,
  }
end

def print_usage
  STDERR.puts "Usage: #{$0} <MMDB file> [IP file]"
  STDERR.puts ""
  STDERR.puts "Benchmark by reading IPs from the IP file and looking up each one in the MMDB file."
end

def benchmark(reader, file)
  n = 0
  count = 200_000
  start = Time.now.to_f
  File.open(file) do |fh|
    fh.each do |line|
      n += 1
      line.strip!

      reader.get(line)

      if n % 1000 == 0
        write_status(start, n)
      end
      if n == count
        return
      end
    end
  end
end

def write_status(start, n)
  now = Time.now.to_f
  elapsed = now - start
  rate = 1.0 * n / elapsed
  puts '%d @ %.2f lookups per second (%d seconds elapsed)' % [n, rate, elapsed]
end

if main
  exit 0
end

exit 1
