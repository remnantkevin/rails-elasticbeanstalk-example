# Ruby on Rails on Elastic Beanstalk Example

## Setup

### Required tools

- Ruby `2.7.5-p203`
- RubyGems `3.3.7`
- Puma `5.6.2`
- Bundler` 2.3.7`
- Node `16.14.0`
- Yarn `1.22.17`
- PostgreSQL `13.3`
- Python `3.10.x`
- AWS CLI `2.4.x`
- Elastic Beanstalk CLI `3.20.x`
- I use the `asdf` version manager, which is why there is a `.tool-versions` file

### AWS

- An IAM user with the relevant [Elastic Beanstalk permissions](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/AWSHowTo.iam.managed-policies.html) and the `AmazonSSMFullAccess` Systems Manager policy.
  - This user also needs to be set up as a local AWS CLI profile.
  - The [launch script](scripts/launch.rb) assumes there are string parameters in your AWS Parameter Store which are named as follows:
    - `/[environment name]/[type of application]/[name]`
    - e.g. `/production/web/RAILS_MASTER_KEY` and `/staging/worker/DBPassword`
    - see the launch script for more details
    - `[type of application]` possible values: `web`, `worker`
    - `[name]` possible values: `RAILS_MASTER_KEY`, `DBUser`, `DBPassword`
- [An Elastic Beanstalk service role named `aws-elasticbeanstalk-service-role`](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/iam-servicerole.html).
- [An EC2 service role named `aws-elasticbeanstalk-ec2-role`](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/iam-instanceprofile.html).
- [Set up an SSH key-value pair named `aws-eb`](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb3-ssh.html).

## Elastic Beanstalk platform

This project uses the [`Ruby 2.7 AL2 version 3.4.3`](https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platform-history-ruby.html) platform, which provides the following tools by default (as at `2022-03-05`):

- Ruby `2.7.5-p203`
- RubyGems `3.3.7`
- Puma `5.6.2`
- Bundler` 2.3.7`
- Node `16.14.0`
- Postgresql `9.2`

### Database

In order to use a more up-to-date version of PostgreSQL (that is compatible with the `pg` gem), we need to update the version of the `postgresql` tool that is available to the app in the EB containers.

See the [`00_upgrade_to_postgresql13.sh`](.platform/hooks/prebuild/00_upgrade_to_postgresql13.sh) hook for how this update is done.

`13.3` is also used when creating the PostgreSQL RDS instance that is coupled to the EB environment.

### Procfile

A different `Procfile` is needed in the web application than in the worker application. Both files exist in this repo ([`Procfile.web`](Procfile.web) and [`Procfile.worker`](Procfile.worker)), but only one gets used in the specific application (see [`02_use_correct_procfile.sh`](.platform/hooks/prebuild/02_use_correct_procfile.sh) for more details).

## Using the example

- Copy and modify the EB CLI [sample config file](.elasticbeanstalk/config.sample.yml), so that it can be used as a EB CLI config file.
- See the [launch script](scripts/launch.rb) for details on how to deploy new web and worker applications.
- To deploy code to an existing environment, use `eb deploy` as usual, making sure to update the EB CLI config file (`.elasticbeanstalk/config.yml`) with the correct environment name and application name beforehand.

## TODO

- more details on set up
- more detailed explanantion of architecture and reasons why things were done the way they were
- limitations of EB
- limitations of the current setup
- connect app to images/files on S3
- security considerations (e.g. worker is open to the public internet as it has an elastic IP, and plain strings are used for parameters in the Parameter Store)
- launch script could be done using AWS Ruby SDK, CloudFormation, AWS CDK, etc.
- try composing EB environments / linked / grouped environments
- note the dependency between web and worker -- we needs to be created first, and worker needs to be terminated first
