#!/usr/bin/env ruby
# frozen_string_literal: true

require 'maxmind/db'

def main
  args = parse_args
  return false if args.nil?

  reader = MaxMind::DB.new(args[:database], mode: MaxMind::DB::MODE_MEMORY)
  benchmark(reader, args[:ip_file])
  true
end

def parse_args
  if ARGV.length != 2
    print_usage
    return nil
  end

  database = ARGV[0]
  ip_file  = ARGV[1]

  {
    database: database,
    ip_file: ip_file,
  }
end

def print_usage
  # rubocop:disable Style/StderrPuts
  $stderr.puts "Usage: #{$PROGRAM_NAME} <MMDB file> <IP file>"
  $stderr.puts
  $stderr.puts 'Benchmark by reading IPs from the IP file and looking up each one in the MMDB file.'
  # rubocop:enable Style/StderrPuts
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

      write_status(start, n) if n % 1000 == 0
      break if n == count
    end
  end
end

def write_status(start, count)
  now = Time.now.to_f
  elapsed = now - start
  rate = 1.0 * count / elapsed
  puts format('%d @ %.2f lookups per second (%d seconds elapsed)', count, rate, elapsed)
end

exit 0 if main

exit 1
