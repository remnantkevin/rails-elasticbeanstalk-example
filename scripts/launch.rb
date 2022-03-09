#!/usr/bin/env ruby

require "bundler/setup"
require "dry/cli"
require "json"
require "securerandom"
require 'open3'

PLATFORM_ARN = "arn:aws:elasticbeanstalk:ap-southeast-2::platform/Ruby 2.7 running on 64bit Amazon Linux 2/3.4.3"

module Commands
  extend Dry::CLI::Registry

  class Version < Dry::CLI::Command
    desc "Print version"

    def call(*)
      puts "1.0.0"
    end
  end

  class Create < Dry::CLI::Command
    desc "Create a new web application, worker application, and environments for each, on EB."

    option :application, type: :string, required: true, desc: "Name of the EB application"
    option :environment, type: :string, required: true, values: [:production, :staging], desc: "Type of environment to create"

    def call(application:, environment:, **)
      current_directory = Dir.pwd

      ##########################
      # Web
      ##########################

      web_application_name = "#{application}-web"
      web_environment_name = "#{web_application_name}-#{environment}"
      web_application_unique_appversion_name = "#{web_application_name}_appversion_#{SecureRandom.uuid}"
      web_application_unique_template_name = "#{web_application_name}_template_#{SecureRandom.uuid}"
      
      appversion_args = [
        "--create",
        "--application #{web_application_name}",
        "--label #{web_application_unique_appversion_name}"
      ]
      puts appversion_args

      Open3.popen3("eb appversion #{appversion_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end

      create_configuration_template_args = [
        "--application-name #{web_application_name}",
        "--template-name #{web_application_unique_template_name}",
        "--platform-arn \"#{PLATFORM_ARN}\"",
        "--option-settings \"file://#{current_directory}/.ebextensions/web.config.json\""
      ]
      puts create_configuration_template_args

      Open3.popen3("aws elasticbeanstalk create-configuration-template #{create_configuration_template_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end
      
      option_overrides = [
        { Namespace: "aws:rds:dbinstance", OptionName: "DBUser", Value: get_parameter_value("/#{environment}/web/DBUser") },
        { Namespace: "aws:rds:dbinstance", OptionName: "DBPassword", Value: get_parameter_value("/#{environment}/web/DBPassword") },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RACK_ENV", Value: environment },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RAILS_MASTER_KEY", Value: get_parameter_value("/#{environment}/web/RAILS_MASTER_KEY") },
      ]

      create_environment_args = [
        "--environment-name #{web_environment_name}",
        "--application-name #{web_application_name}",
        "--template-name #{web_application_unique_template_name}",
        "--version-label #{web_application_unique_appversion_name}",
        "--option-settings '#{option_overrides.to_json}'"
      ]
      puts create_environment_args
      puts "aws elasticbeanstalk create-environment #{create_environment_args.join(' ')}"

      Open3.popen3("aws elasticbeanstalk create-environment #{create_environment_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end


      ##########################
      # Worker
      ##########################

      worker_application_name = "#{application}-worker"
      worker_environment_name = "#{worker_application_name}-#{environment}"
      worker_application_unique_appversion_name = "#{worker_application_name}_appversion_#{SecureRandom.uuid}"
      worker_application_unique_template_name = "#{worker_application_name}_template_#{SecureRandom.uuid}"

      worker_appversion_args = [
        "--create",
        "--application #{worker_application_name}",
        "--label #{worker_application_unique_appversion_name}"
      ]
      puts worker_appversion_args

      Open3.popen3("eb appversion #{worker_appversion_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end

      worker_create_configuration_template_args = [
        "--application-name #{worker_application_name}",
        "--template-name #{worker_application_unique_template_name}",
        "--platform-arn \"#{PLATFORM_ARN}\"",
        "--option-settings \"file://#{current_directory}/.ebextensions/worker.config.json\""
      ]
      puts worker_create_configuration_template_args
      puts "aws elasticbeanstalk create-configuration-template #{worker_create_configuration_template_args.join(' ')}"

      Open3.popen3("aws elasticbeanstalk create-configuration-template #{worker_create_configuration_template_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end

      rds = get_rds_instance_data(web_environment_name)
      puts rds
      sg = get_web_launch_security_group(web_environment_name, web_application_name)
      puts sg
      option_overrides = [
        { Namespace: "aws:autoscaling:launchconfiguration", OptionName: "SecurityGroups", Value: sg },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RACK_ENV", Value: environment },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RAILS_MASTER_KEY", Value: get_parameter_value("/#{environment}/web/RAILS_MASTER_KEY") },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RDS_DB_NAME", Value: rds[:db_name] },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RDS_HOSTNAME", Value: rds[:host_name] },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RDS_PORT", Value: "5432" },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RDS_USERNAME", Value: get_parameter_value("/#{environment}/web/DBUser") },
        { Namespace: "aws:elasticbeanstalk:application:environment", OptionName: "RDS_PASSWORD", Value: get_parameter_value("/#{environment}/web/DBPassword") },

      ]
      puts option_overrides

      worker_create_environment_args = [
        "--environment-name #{worker_environment_name}",
        "--application-name #{worker_application_name}",
        "--template-name #{worker_application_unique_template_name}",
        "--version-label #{worker_application_unique_appversion_name}",
        "--option-settings '#{option_overrides.to_json}'"
      ]
      puts worker_create_environment_args
      puts "aws elasticbeanstalk create-environment #{worker_create_environment_args.join(' ')}"

      Open3.popen3("aws elasticbeanstalk create-environment #{worker_create_environment_args.join(' ')}") do |stdout, stderr, status, thread|
        while line=stderr.gets do 
          puts(line) 
        end
      end
            
    end

    def get_parameter_value(name)
      parameter_value, error, status = Open3.capture3("aws ssm get-parameter --name \"#{name}\" --query \"Parameter.Value\" --output json")
      JSON.parse(parameter_value)
    end

    def get_rds_instance_data(web_environment_name)
      raw_instance_data, error, status = Open3.capture3("aws rds describe-db-instances --output json --query \"DBInstances[].{DBName: DBName, HostName: Endpoint.Address, TagList: TagList[?Key=='elasticbeanstalk:environment-name']}\"")
      instance_data = JSON.parse(raw_instance_data).filter do |instance|
        instance["TagList"].any? { |tag| tag["Key"] ==  "elasticbeanstalk:environment-name" && tag["Value"] == web_environment_name }
      end.first
      { db_name: instance_data["DBName"], host_name: instance_data["HostName"] }
    end

    def get_web_launch_security_group(web_environment_name, web_application_name)
      raw_security_group_data, error, status = Open3.capture3("aws elasticbeanstalk describe-configuration-settings --environment-name #{web_environment_name} --application-name #{web_application_name} --output text --query \"ConfigurationSettings[0].OptionSettings[?Namespace=='aws:autoscaling:launchconfiguration' && OptionName=='SecurityGroups'].Value\"")
      raw_security_group_data
    end
  end

  register "version", Version, aliases: ["v", "-v", "--version"]
  register "create", Create, aliases: ["c"]
end

Dry::CLI.new(Commands).call
