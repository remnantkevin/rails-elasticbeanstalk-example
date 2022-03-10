# README

# Explain setup

asdf + .tool-versions

`gem update --system 3.3.7 --no-document`

`gem install bundler -v 2.3.7`

remove default bundler (e.g. 2.1.4)

- e.g. `rm -rf /Users/[username]/.asdf/installs/ruby/2.7.5/lib/ruby/gems/2.7.0/gems/bundler-2.1.4/`

# Elastic Beanstalk platform

This project uses the [`Ruby 2.7 AL2 version 3.4.3`](https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platform-history-ruby.html) platform, which provides the following tools by default (as at `2022-03-05`):

- Ruby `2.7.5-p203`
- RubyGems `3.3.7`
- Puma `5.6.2`
- Bundler` 2.3.7`
- Node `16.14.0`
- Yarn `1.22.17` (not available on command line)
- Postgresql `9.2`

# Database

In order to use a more up to date version of PostgreSQL (that is compatible with the `pg` gem), we need to update the version of the `postgresql` tool that is available to the app in the EB containers.

To do this we configure the ... to use the `yum` package manager and the latest version of the `postgresql` tool available in the [`amazon-linux-extras` library](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-install-extras-library-software/). The latest version (as at `2022-03-05`) is `13.3`.

`13.3` is also used when creating the PostgreSQL RDS instance that is coupled to the EB environment.

# TODO

- cleanup / comment out puts in launch script

- images/files in S3
