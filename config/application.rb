require_relative "boot"

require "rails/all"

# Explicitly require the Engine code at the top of your config/application.rb file, immediately after Rails is
# required and before Bundler requires the Rails' groups. This is necessary because the mountable engine is an
# optional feature of GoodJob.
#
# NOTE: If you find the dashboard fails to reload due to a routing error and uninitialized constant
#       GoodJob::ExecutionsController, this is likely because you are not requiring the engine early enough.
#
# For more info, see https://github.com/bensheldon/good_job#dashboard
require 'good_job/engine'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use good_job as ActiveJob backend.
    config.active_job.queue_adapter = :good_job

    # Configure good_job.
    config.good_job.preserve_job_records = true # keep history of processed jobs for easier debugging 
  end
end
