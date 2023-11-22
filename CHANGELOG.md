# Changelog

## 1.2.0 (2023-11-22)

* Ruby 2.4 is no longer supported. If you're using Ruby 2.4, please use
  version 1.1.1 of this gem.
* `Object#respond_to?` is no longer called on every read. Pull request by
  Jean byroot Boussier. GitHub #65.
* The `get` and `get_prefix_length` methods now accept the IP addresses as
  `IPAddr` objects. Strings are still accepted too. Pull request by Eddie
  Lebow. GitHub #69.

## 1.1.1 (2020-06-23)

* Fixed the memory reader's inspect method to no longer attempt to modify a
  frozen string. Pull request by Tietew. GitHub #35.

## 1.1.0 (2020-01-08)

* The method `get_with_prefix_length` was added. This method returns both
  the record and the network prefix length associated with the record in
  the database.
* Simplified a check for whether to return early in the decoder. Pull
  request by Ivan Palamarchuk. GitHub #12.
* Support for Ruby 2.3 was dropped since it is now end of life.

## 1.0.0 (2019-01-04)

* We no longer include the database's buffer in inspect output. This avoids
  showing excessive output when creating a memory reader in irb. Reported
  by Wojciech Wnętrzak. GitHub #6.

## 1.0.0.beta (2018-12-24)

* Initial implementation.
