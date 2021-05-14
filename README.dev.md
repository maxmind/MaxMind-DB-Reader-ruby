# How to release
* Ensure tests pass: `rake`
* Update changelog: Set version and release date
* Set version in `maxmind-db.gemspec`
* Add them: `git add -p`
* Create a branch e.g. `horgh/release` and switch to it.
  * `main` is protected.
* Commit: `git commit -m v1.0.0`
* Tag: `git tag -a v1.0.0 -m v1.0.0`
* Clean up to be sure nothing stray gets into gem: `git clean -dxff`
* Create `.gem` file: `gem build maxmind-db.gemspec`
* Complete prerequisites (see below)
  * You only need to do this once. You can tell if this is necessary if you
    are lacking `:rubygems_api_key` in `~/.local/share/gem/credentials`
    (previously `~/.gem/credentials`)
* Upload to rubygems.org: `gem push maxmind-db-1.0.0.gem`
* Push: `git push`
* Push tag: `git push --tags`
* Make a PR and get it merged.
* Double check it looks okay at https://rubygems.org/gems/maxmind-db and
  https://www.rubydoc.info/gems/maxmind-db


# Prerequisites

## Step 1
Sign up for an account at rubygems.org if you don't have one.

Enable multi factor authentication (for both UI and API).


## Step 2
Ask someone who is an owner of the gem to add you as one.

They do this by using the `gem owner` command
([docs](https://guides.rubygems.org/command-reference/#gem-owner)).


## Step 3
Run `gem signin`. This will prompt you for your username and password, and
then create an API key for you. Select the scopes `index_rubygems` and
`push_rubygem` (I'm not sure the former is required, but anyway).

Note you may need an up to date version of rubygems to do this as I believe
support for API keys like this is a newer addition.
