# rake production radiant:extensions:comments:migrate
class AddSpamColumn < ActiveRecord::Migration
  def self.up
    add_column :comments, :spam, :boolean, :default => false
  end
  
  def self.down
    remove_column :comments, :spam
  end
end

