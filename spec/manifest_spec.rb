require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'stringio'

require 'models/user'
require 'models/post'

describe "Manifest" do

  before(:all) do
    load_core_schema
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
  end

end

