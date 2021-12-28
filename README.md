# MaxMind DB Reader Ruby API

## Description

This is the Ruby API for reading [MaxMind
DB](https://maxmind.github.io/MaxMind-DB/) files. MaxMind DB is a binary
file format that stores data indexed by IP address subnets (IPv4 or IPv6).


## Installation

```
gem install maxmind-db
```

## Usage

```ruby
require 'maxmind/db'

reader = MaxMind::DB.new('GeoIP2-City.mmdb', mode: MaxMind::DB::MODE_MEMORY)

record = reader.get('1.1.1.1')
if record.nil?
  puts '1.1.1.1 was not found in the database'
else
  puts record['country']['iso_code']
  puts record['country']['names']['en']
end

reader.close
```

For more information see the
[documentation](https://www.rubydoc.info/gems/maxmind-db).

## Requirements

This code requires Ruby version 2.5 or higher.

## Contributing

Patches and pull requests are encouraged. Please include unit tests
whenever possible.

## Support

Please report all issues with this code using the [GitHub issue
tracker](https://github.com/maxmind/MaxMind-DB-Reader-ruby/issues).

If you are having an issue with a MaxMind service that is not specific to the
client API, please see [our support page](https://www.maxmind.com/en/support).

## Versioning

This library uses [Semantic Versioning](https://semver.org/).

## Copyright and License

This software is Copyright (c) 2018 - 2021 by MaxMind, Inc.

This is free software, licensed under the [Apache License, Version
2.0](LICENSE-APACHE) or the [MIT License](LICENSE-MIT), at your option.
