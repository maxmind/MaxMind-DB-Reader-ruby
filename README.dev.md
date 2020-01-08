# How to release
* Update dependencies and commit: `bundle update`
* Update changelog and set release date
* Bump version in `maxmind-db.gemspec`
* Commit: `git commit -m v1.0.0`
* Tag: `git tag -a v1.0.0 -m v1.0.0`
* Clean up to be sure nothing stray gets into gem: `git clean -dxff`
* Create `.gem` file: `gem build maxmind-db.gemspec`
* Complete prerequisites (see below)
* Upload to rubygems.org: `gem push maxmind-db-1.0.0.gem`
* Push: `git push`
* Push tag: `git push --tags`
* Double check it looks okay at https://rubygems.org/gems/maxmind-db and
  https://www.rubydoc.info/gems/maxmind-db


# Prerequisites

## Step 1
Sign up for an account at rubygems.org if you don't have one.

Enable multi factor authentication.


## Step 2
Ask someone who is an owner of the gem to add you as one.

They do this by using the `gem owner` command
([docs](https://guides.rubygems.org/command-reference/#gem-owner)).


## Step 3
Go to your rubygems.org profile and find the curl command to run to
download your API key.
