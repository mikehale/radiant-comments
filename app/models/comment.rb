require 'akismet'

class Comment < ActiveRecord::Base
  belongs_to :page, :counter_cache => true
  validates_presence_of :author, :author_email, :content
  
  before_save :auto_approve
  before_save :apply_filter
    
  def self.per_page
    50
  end
  
  def request=(request)
    self.author_ip = request.remote_ip
    self.user_agent = request.env['HTTP_USER_AGENT']
    self.referrer = request.env['HTTP_REFERER']
  end
  
  def akismet
    @akismet ||= Akismet.new(Radiant::Config['comments.akismet_key'], Radiant::Config['comments.akismet_url'])
  end
  
  def auto_approve
    if Radiant::Config['comments.auto_approve'] == "true" && akismet.verify?
      result = akismet.ham?(akismet_attributes)
      if result
        self.approved_at = Time.now
        RAILS_DEFAULT_LOGGER.debug("Comments: Auto-approving comment with akismet.")
      end
      result
    end
  end

  def unapproved?
    !approved?
  end
  
  def approved?
    !approved_at.nil?
  end
  
  def approve!
    self.update_attribute(:approved_at, Time.now)
    akismet.submit_ham(akismet_attributes)
  end

  def unapprove!
    self.update_attribute(:approved_at, nil)
    akismet.submit_spam(akismet_attributes)
  end
  
  private
  
    def akismet_attributes
      {:user_ip => author_ip,
      :referrer => referrer,
      :permalink => page.url,
      :comment_type => "comment",
      :comment_author => author,
      :comment_author_email => author_email,
      :comment_author_url => author_url,
      :comment_content => content}
    end
    
    def apply_filter
      self.content_html = filter.filter(content)
    end
    
    def filter
      filtering_enabled? && filter_from_form || SimpleFilter.new
    end
    
    def filter_from_form
      TextFilter.descendants.find { |f| f.filter_name == filter_id }
    end
    
    def filtering_enabled?
      Radiant::Config['comments.filters_enabled'] == "true"
    end
  
  class SimpleFilter
    include ERB::Util
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::TagHelper
    
    def filter(content)
      simple_format(h(content))
    end
  end
  
  class AntispamWarning < StandardError; end
end
