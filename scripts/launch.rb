#!/usr/bin/env ruby

require 'bundler/setup'
require 'dry/cli'
require 'json'
require 'securerandom'
require 'open3'

PLATFORM_ARN = 'arn:aws:elasticbeanstalk:ap-southeast-2::platform/Ruby 2.7 running on 64bit Amazon Linux 2/3.4.3'

module Commands
  extend Dry::CLI::Registry

  class Version < Dry::CLI::Command
    desc 'Print version'

    def call(*)
      puts '1.0.0'
    end
  end

  class Create < Dry::CLI::Command
    desc 'Create a new web application, worker application, and environments for each, on EB.'

    option :application, type: :string,
                         required: true,
                         desc: 'Name of the EB application'
    option :environment, type: :string,
                         required: true,
                         values: %i[production staging],
                         desc: 'Type of environment to create'
    option :profile, type: :string,
                     required: true,
                     desc: 'Name of aws cli profile to use'

    def call(application:, environment:, profile:, **)
      current_directory = Dir.pwd

      ##########################
      # Web
      ##########################

      web_application_name = "#{application}-web"
      web_environment_name = "#{web_application_name}-#{environment}"
      web_application_unique_appversion_name = "#{web_application_name}_appversion_#{SecureRandom.uuid}"
      web_application_unique_template_name = "#{web_application_name}_template_#{SecureRandom.uuid}"

      create_eb_application_and_version(web_application_name, web_application_unique_appversion_name, profile)

      create_eb_configuration_template(web_application_name, web_application_unique_template_name, current_directory,
                                       profile, 'web')

      web_option_overrides = [
        {
          Namespace: 'aws:rds:dbinstance',
          OptionName: 'DBUser',
          Value: get_parameter_value("/#{environment}/web/DBUser", profile)
        },
        {
          Namespace: 'aws:rds:dbinstance',
          OptionName: 'DBPassword',
          Value: get_parameter_value("/#{environment}/web/DBPassword", profile)
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RACK_ENV',
          Value: environment
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RAILS_MASTER_KEY',
          Value: get_parameter_value("/#{environment}/web/RAILS_MASTER_KEY", profile)
        }
      ]
      # puts web_option_overrides

      create_eb_environment(web_application_name, web_environment_name, web_application_unique_appversion_name,
                            web_application_unique_template_name, web_option_overrides, profile)

      ##########################
      # Worker
      ##########################

      wait_for_environment_to_be_ready(web_environment_name, profile)

      worker_application_name = "#{application}-worker"
      worker_environment_name = "#{worker_application_name}-#{environment}"
      worker_application_unique_appversion_name = "#{worker_application_name}_appversion_#{SecureRandom.uuid}"
      worker_application_unique_template_name = "#{worker_application_name}_template_#{SecureRandom.uuid}"

      create_eb_application_and_version(worker_application_name, worker_application_unique_appversion_name, profile)

      create_eb_configuration_template(worker_application_name, worker_application_unique_template_name,
                                       current_directory, profile, 'worker')

      rds_hostname = get_rds_instance_hostname(web_environment_name, profile)
      security_group_name = get_launch_config_security_group(web_environment_name, web_application_name, profile)
      # puts rds_hostname
      # puts security_group_name

      worker_option_overrides = [
        {
          Namespace: 'aws:autoscaling:launchconfiguration',
          OptionName: 'SecurityGroups',
          Value: security_group_name # allows a worker EC2 instance to be able to connect to the web RDS instance
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RACK_ENV',
          Value: environment
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RAILS_MASTER_KEY',
          Value: get_parameter_value("/#{environment}/worker/RAILS_MASTER_KEY", profile)
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RDS_DB_NAME',
          Value: 'ebdb'
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RDS_HOSTNAME',
          Value: rds_hostname
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RDS_PORT',
          Value: '5432'
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RDS_USERNAME',
          Value: get_parameter_value("/#{environment}/worker/DBUser", profile)
        },
        {
          Namespace: 'aws:elasticbeanstalk:application:environment',
          OptionName: 'RDS_PASSWORD',
          Value: get_parameter_value("/#{environment}/worker/DBPassword", profile)
        }

      ]
      # puts worker_option_overrides

      create_eb_environment(worker_application_name, worker_environment_name,
                            worker_application_unique_appversion_name, worker_application_unique_template_name,
                            worker_option_overrides, profile)

      wait_for_environment_to_be_ready(worker_environment_name, profile)
    end

    def create_eb_application_and_version(application_name, unique_appversion_name, profile)
      appversion_args = [
        '--create',
        "--application #{application_name}",
        "--label #{unique_appversion_name}",
        "--profile #{profile}"
      ]
      # puts appversion_args

      output, _error, _status = Open3.capture3("eb appversion #{appversion_args.join(' ')}")
      # puts output
      puts "Created '#{application_name}' application version '#{unique_appversion_name}'"
    end

    def create_eb_configuration_template(application_name, unique_template_name, current_directory, profile, type)
      create_configuration_template_args = [
        "--application-name #{application_name}",
        "--template-name #{unique_template_name}",
        "--platform-arn \"#{PLATFORM_ARN}\"",
        "--option-settings \"file://#{current_directory}/.ebextensions/#{type}.config.json\"",
        "--profile #{profile}"
      ]
      # puts create_configuration_template_args

      output, _error, _status = Open3.capture3(
        "aws elasticbeanstalk create-configuration-template #{create_configuration_template_args.join(' ')}"
      )
      # puts output
      puts "Created '#{application_name}' configuration template '#{unique_template_name}'"
    end

    def create_eb_environment(application_name, environment_name, unique_appversion_name, unique_template_name,
                              option_overrides, profile)
      create_environment_args = [
        "--environment-name #{environment_name}",
        "--application-name #{application_name}",
        "--template-name #{unique_template_name}",
        "--version-label #{unique_appversion_name}",
        "--option-settings '#{option_overrides.to_json}'",
        "--profile #{profile}"
      ]
      # puts create_environment_args
      # puts "aws elasticbeanstalk create-environment #{create_environment_args.join(' ')}"

      output, _error, _status = Open3.capture3(
        "aws elasticbeanstalk create-environment #{create_environment_args.join(' ')}"
      )
      # puts output
      puts "Started creating '#{environment_name}' environment..."
    end

    def wait_for_environment_to_be_ready(environment_name, profile)
      environment_status = get_environment_status(environment_name, profile)

      while environment_status != 'Ready'
        puts 'Waiting 1 minute before checking status again...'
        sleep(60)

        environment_status = get_environment_status(environment_name, profile)
      end
    end

    def get_environment_status(environment_name, profile)
      describe_environment_health_args = [
        "--environment-name #{environment_name}",
        '--attribute-names Status',
        '--output json',
        "--profile #{profile}"
      ]

      puts "Checking status of '#{environment_name}'..."

      output, _error, _status = Open3.capture3(
        "aws elasticbeanstalk describe-environment-health #{describe_environment_health_args.join(' ')}"
      )
      # puts output

      status = JSON.parse(output)['Status']
      puts "Status: #{status}"

      status
    end

    def get_parameter_value(name, profile)
      parameter_value, _error, _status = Open3.capture3("aws ssm get-parameter --profile #{profile} --name \"#{name}\" --query \"Parameter.Value\" --output json")
      JSON.parse(parameter_value)
    end

    def get_rds_instance_hostname(environment_name, profile)
      environment_id, _error, _status = Open3.capture3("aws elasticbeanstalk describe-environments --environment-name #{environment_name}  --profile #{profile} --query \"Environments[0].EnvironmentId\" --output text")
      environment_id = environment_id.strip

      cloudformation_stack_outputs, _error, _status = Open3.capture3("aws cloudformation describe-stacks --output json --profile #{profile} --query \"Stacks[?contains(StackName, '#{environment_id}')].Outputs[]\"")

      JSON.parse(cloudformation_stack_outputs).find do |x|
        x['OutputKey'] == 'AWSEBRDSDatabaseProperties'
      end.fetch('OutputValue').split(',')[1]
    end

    def get_launch_config_security_group(environment_name, application_name, profile)
      describe_configuration_settings_args = [
        "--environment-name #{environment_name}",
        "--application-name #{application_name}",
        '--output text',
        "--query \"ConfigurationSettings[0].OptionSettings[?Namespace=='aws:autoscaling:launchconfiguration' && OptionName=='SecurityGroups'].Value\"",
        "--profile #{profile}"
      ]

      raw_security_group_data, _error, _status = Open3.capture3(
        "aws elasticbeanstalk describe-configuration-settings #{describe_configuration_settings_args.join(' ')}"
      )
      raw_security_group_data.strip
    end
  end

  register 'version', Version, aliases: ['v', '-v', '--version']
  register 'create', Create, aliases: ['c']
end

Dry::CLI.new(Commands).call
