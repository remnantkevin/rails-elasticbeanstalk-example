class MyTestJob < ApplicationJob
  queue_as :default

  def perform(article)
    logger.info("Performing job...")
    logger.info("JOB ID: #{article.id}")

    puts "puts logger:"
    puts logger
    
    article_latest = Article.find(article.id)
    article_latest.title = "Change from job"
    article_latest.save!

    logger.info("Job completed")
  end
end
