require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'stringio'

require 'models/user'
require 'models/post'

describe "Manifest" do

  before(:all) do
    load_core_schema
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.add_index(:posts, :user_id)
      ActiveRecord::Migration.add_column(:posts, :number, :integer)
      ActiveRecord::Migration.add_index(:posts, :number)
      ActiveRecord::Migration.add_index(:posts, [:user_id, :author_id], :unique => true)
      ActiveRecord::Migration.add_index(:posts, [:number, :user_id, :author_id], :unique => true)
    end
  end

  context "string" do
    let(:comment_manifest) do
      Comment.manifest
    end

    let(:post_manifest) do
      Post.manifest
    end

    it "should include model name" do
      comment_manifest.should match(%r{= class Comment})
    end

    it "should include column accessors" do
      comment_manifest.should match(%r{[*] text :body})
      comment_manifest.should match(%r{[*] integer :post_id})
    end

    it "should include associations" do
      comment_manifest.should match(%r{[*] belongs_to :post})
      post_manifest.should match(%r{[*] has_many :comments})
    end

    it "should include foreign keys" do
      comment_manifest.should match(%r{:post_id.*:references => \[:posts, :id\]})
    end

    it "should include indexes" do
      post_manifest.should match(%r{:number.*:index =>})
      post_manifest.should match(%r{:user_id.*:index =>})
      post_manifest.should match(%r{:author_id.*:index =>.*:with=>\[:user_id\]})
    end

    it "should include additional indexes" do
      post_manifest.should match(%r{== additional indexes})
      post_manifest.should match(%r{index \[:number, :user_id, :author_id\]})
    end
  end

end

