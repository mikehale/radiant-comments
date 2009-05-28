class Admin::CommentsController < ApplicationController
  only_allow_access_to :edit, :update, :enable, :approve, :unapprove, :destroy,
    :when => [:developer, :admin],
    :denied_message => "You must have admin or developer privileges to execute this action."

  def index
    conditions = case params[:status]
    when "approved"
      "comments.approved_at IS NOT NULL"
    when "unapproved"
      {:approved_at => nil, :spam => false}
    when "spam"
      {:spam => true}
    else
      nil
    end
    @page = Page.find(params[:page_id]) if params[:page_id]
    @comments = if @page.nil? 
      Comment.paginate(:page => params[:page], :order => "created_at DESC", :conditions => conditions)
    else
      @page.comments.paginate(:page => params[:page], :conditions => conditions)
    end

    respond_to do |format|
      format.html
      format.csv  { render :text => @comments.to_csv }
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy
    announce_comment_removed
    ResponseCache.instance.expire_response(@comment.page.url)
    redirect_to_back
  end
  
  def destroy_unapproved
    flash[:notice] = if Comment.destroy_unapproved
      "You have removed all unapproved comments."
    else
      "I was unable to remove all unapproved comments."
    end
    redirect_to_back
  end

  def destroy_spam
    flash[:notice] = if Comment.destroy_spam
      "You have removed all spam comments."
    else
      "I was unable to remove all spam comments."
    end
    redirect_to_back
  end

  def edit
    @comment = Comment.find(params[:id])
  end

  def update
    @comment = Comment.find(params[:id])
    begin
      TextFilter.descendants.each do |filter| 
        @comment.content_html = filter.filter(@comment.content) if filter.filter_name == @comment.filter_id    
      end
      @comment.update_attributes(params[:comment])
      ResponseCache.instance.clear
      flash[:notice] = "Comment Saved"
      redirect_to :action => :index
    rescue Exception => e
      flash[:notice] = "There was an error saving the comment"
    end
  end

  def enable
    @page = Page.find(params[:page_id])
    @page.enable_comments = 1
    @page.save!
    flash[:notice] = "Comments has been enabled for #{@page.title}"
    redirect_to page_index_path
  end

  def approve
    @comment = Comment.find(params[:id])
    begin
      @comment.approve!
    rescue Comment::AntispamWarning => e
      antispamnotice = "The antispam engine gave a warning: #{e}<br />"
    end
    ResponseCache.instance.expire_response(@comment.page.url)
    flash[:notice] = "Comment was successfully approved on page #{@comment.page.title}" + (antispamnotice ? " (#{antispamnotice})" : "")
    redirect_to_back
  end
  
  def redirect_to_back
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to :action => :index
  end

  def unapprove
    @comment = Comment.find(params[:id])
    begin
      @comment.unapprove!
    rescue Comment::AntispamWarning => e
      antispamnotice = "The antispam engine gave a warning: #{e}"
    end
    ResponseCache.instance.expire_response(@comment.page.url)
    flash[:notice] = "Comment was successfully unapproved on page #{@comment.page.title}" + (antispamnotice ? " (#{antispamnotice})" : "" )
    redirect_to_back
  end

  def is_spam
    @comment = Comment.find(params[:id])
    @comment.unapprove!
    ResponseCache.instance.expire_response(@comment.page.url)
    flash[:notice] = "Comment was successfully marked as spam."
    redirect_to_back
  end

  protected

  def announce_comment_removed
    flash[:notice] = "The comment was successfully removed from the site."
  end

end