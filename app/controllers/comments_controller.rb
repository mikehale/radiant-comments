class CommentsController < ApplicationController
  
  no_login_required
  skip_before_filter :verify_authenticity_token
  before_filter :find_page
  before_filter :set_host

  def index
    @page.selected_comment = @page.comments.find_by_id(flash[:selected_comment])
    @page.request, @page.response = request, response
    render :text => @page.render
  end
  
  def create
    comment = @page.comments.build(params[:comment])
    comment.request = request
    comment.save!
    
    clear_single_page_cache(comment)
    CommentMailer.deliver_comment_notification(comment) if Radiant::Config['comments.notification'] == "true"
    
    flash[:selected_comment] = comment.id
    redirect_to "#{@page.url}comments#comment-#{comment.id}"
  rescue ActiveRecord::RecordInvalid
    @page.last_comment = comment
    @page.request, @page.response = request, response
    render :text => @page.render
 # rescue Comments::MollomUnsure
    #flash, en render :text => @page.render
  end
  
  private
  
    def find_page
      url = params[:url]
      url.shift if defined?(SiteLanguage) && SiteLanguage.count > 1
      @page = Page.find_by_url(url.join("/"))
    end
    
    def set_host
      CommentMailer.default_url_options[:host] = request.host_with_port
    end

    def clear_single_page_cache(comment)
      if comment && comment.page
        Radiant::Cache::EntityStore.new.purge(comment.page.url)
        Radiant::Cache::MetaStore.new.purge(comment.page.url)
      end
    end
  
end
