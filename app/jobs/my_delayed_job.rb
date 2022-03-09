class MyDelayedJob < ApplicationJob
  queue_as :default

  def perform(article)
    logger.info("Performing MyDelayedJob...")

    article.title = "This title was changed from #{article.title} by MyDelayedJob"
    article.save!

    logger.info("MyDelayedJob completed.")
  end
end