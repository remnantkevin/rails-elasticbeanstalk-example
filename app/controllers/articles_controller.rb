class ArticlesController < ApplicationController
  def index
    @articles = Article.all
  end

  def show
    @article = Article.find(params[:id])
  end

  def new
    @article = Article.new
  end

  def create
    logger.info("Creating article...")

    @article = Article.new(article_params)

    if @article.save
      logger.info("Article saved")
      MyTestJob.perform_later(@article)
      MyDelayedJob.set(wait: 5.minutes).perform_later(@article)
      redirect_to @article
    else
      logger.info("Article failed validation")
      render :new
    end
  end

  private
    def article_params
      params.require(:article).permit(:title, :body)
    end
end
