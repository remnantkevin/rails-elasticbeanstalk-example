class MyTestJob < ApplicationJob
  queue_as :default

  def perform(article)
    logger.info("Performing MyTestJob...")

    article.title = "This title was changed from #{article.title} by MyTestJob"
    article_latest.save!

    logger.info("MyTestJob completed.")
  end
end
