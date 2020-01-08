# Changelog

## Unreleased

* The method `get_with_prefix_length` was added. This method returns both
  the record and the network prefix length associated with the record in
  the database.
* Simplified a check for whether to return early in the decoder. Pull
  request by Ivan Palamarchuk. GitHub #12.
* Support for Ruby 2.3 was dropped since it is now end of life.

## 1.0.0 - 2019-01-04

* We no longer include the database's buffer in inspect output. This avoids
  showing excessive output when creating a memory reader in irb. Reported
  by Wojciech Wnętrzak. GitHub #6.

## 1.0.0.beta - 2018-12-24

* Initial implementation.
