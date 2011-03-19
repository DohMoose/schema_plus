require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'stringio'

describe "Manifest" do

  before(:all) do
    ActiveSchema.config.associations.auto_create = true;
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define do
        connection.tables.each do |table| drop_table table end

        create_table :mspecs do |t|
          t.integer :number,  :index => true
          t.integer :size, :index => true
          t.integer :weight, :index => {:with => :size, :unique => true }
          t.index [:number, :size, :weight], :unique => true
        end

        create_table :mdependents do |t|
          t.integer :mspec_id, :references => :mspecs
        end
      end
    end

    class Mdependent < ActiveRecord::Base
    end

    class Mspec < ActiveRecord::Base
      accepts_nested_attributes_for :mdependents
      has_many :expclit, :class_name => "ManifestAux", :foreign_key => 'manifest_id'
    end

  end

  context "string" do
    let(:mdependent_manifest) do
      Mdependent.manifest
    end

    let(:mspec_manifest) do
      Mspec.manifest
    end

    it "should include model name" do
      mdependent_manifest.should match(%r{= class Mdependent})
    end

    it "should include column accessors" do
      mspec_manifest.should match(%r{[*] integer :size})
      mdependent_manifest.should match(%r{[*] integer :mspec_id})
    end

    it "should include automatic associations" do
      mdependent_manifest.should match(%r{[*] belongs_to :mspec})
      mspec_manifest.should match(%r{[*] has_many :mdependents})
    end

    it "should include explicit associations after reflection" do
      mspec_manifest.should match(%r{[*] has_many :explicit})
    end


    it "should include foreign keys" do
      mdependent_manifest.should match(%r{:mspec_id.*:references => \[:mspecs, :id\]})
    end

    it "should include indexes" do
      mspec_manifest.should match(%r{:number.*:index =>})
      mspec_manifest.should match(%r{:size.*:index =>})
      mspec_manifest.should match(%r{:weight.*:index =>.*:with=>\[:size\]})
    end

    it "should include additional indexes" do
      mspec_manifest.should match(%r{== additional indexes})
      mspec_manifest.should match(%r{index \[:number, :size, :weight\]})
    end
  end

end

