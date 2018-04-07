# coding: utf-8
# Frozen-string-literal: true
# Copyright: Since 2017 Tamanguu GmbH & Co KG - MIT License
# Encoding: utf-8

require 'jekyll-tag-pages'

basedir = 'spec/test/_site1/tag/'
jekyll = basedir + 'jekyll/'
haodezhuyi = basedir + '%E5%A5%BD%E7%9A%84%E4%B8%BB%E6%84%8F/'
plugin = basedir + 'Tag+Pages+Plugin/'
index = 'index.html'

describe Jekyll::TagPages do
  context "no_pagination" do
    it "tag indices exists" do
      expect(File.file? jekyll+index).to be true
      expect(File.file? haodezhuyi+index).to be true
      expect(File.file? plugin+index).to be true
    end

    it "tag jekyll is correct" do
      load jekyll+index
      expect($page_title).to eql('jekyll')
      expect($page_tag).to eql('jekyll')
      expect($page_total_posts).to eql(5)
      expect($page_posts_title).to eql([ "More about Jekyll", "Everything you always wanted to know about Jekyll", "About the plugin", "Welcome to the plugin", "Welcome to Jekyll!" ])
    end

    it "tag 好的主意 is correct" do
      load haodezhuyi+index
      expect($page_title).to eql('好的主意')
      expect($page_tag).to eql('好的主意')
      expect($page_total_posts).to eql(1)
      expect($page_posts_title).to eql([ "Welcome to the plugin" ])
    end

    it "tag Tag Pages Plugin is correct" do
      load plugin+index
      expect($page_title).to eql('Tag Pages Plugin')
      expect($page_tag).to eql('Tag Pages Plugin')
      expect($page_total_posts).to eql(2)
      expect($page_posts_title).to eql([ "About the plugin", "Welcome to the plugin" ])
    end
  end
end
