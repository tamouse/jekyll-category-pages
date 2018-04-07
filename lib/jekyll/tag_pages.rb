# frozen_string_literal: true
# Encoding: utf-8

#
# tag_pages
# Add tag index pages with and without pagination.
#
# (c) since 2017 by Tamanguu GmbH & Co KG
# Written by Dr. Wolfram Schroers <Wolfram.Schroers -at- tamanguu.com>
#
# Copyright: Since 2017 Tamanguu GmbH & Co KG - MIT License
# See the accompanying file LICENSE for licensing conditions.
#

require 'jekyll'

module Jekyll
  module TagPages
    INDEXFILE = 'index.html'

    # Custom generator for generating all index pages based on a supplied layout.
    #
    # Note that this generator uses a layout instead of a regular page template, since
    # it will generate a set of new pages, not merely variations of a single page like
    # the blog index Paginator does.
    class Pagination < Generator
      # This generator is safe from arbitrary code execution.
      safe true
      priority :lowest

      # Generate paginated tag pages if necessary.
      #
      # site - The Site object.
      def generate(site)
        tag_base_path = site.config['tag_path'] || 'tag'
        tag_layout_path = File.join('_layouts/', site.config['tag_layout'] || 'tag_index.html')

        if Paginate::Pager.pagination_enabled?(site)
          # Generate paginated tag pages
          generate_paginated_tags(site, tag_base_path, tag_layout_path)
        else
          # Generate tag pages without pagination
          generate_tags(site, tag_base_path, tag_layout_path)
        end
      end

      # Sort the list of tags and remove duplicates.
      #
      # site - The Site object.
      #
      # Returns an array of strings containing the site's tags.
      def sorted_tags(site)
        tags = []
        site.tags.each_pair do |tag, pages|
          tags.push(tag)
        end
        tags.sort!.uniq!
        return tags
      end

      # Generate the paginated tag pages.
      #
      # site               - The Site object.
      # tag_base_path - String with the base path to the tag index pages.
      # tag_layout    - The name of the basic tag layout page.
      def generate_paginated_tags(site, tag_base_path, tag_layout)
        tags = sorted_tags site

        # Generate the pages
        for tag in tags
          posts_in_tag = site.tags[tag]
          tag_path = File.join(tag_base_path, CGI.escape(tag))
          per_page = site.config['paginate']

          page_number = TagPager.calculate_pages(posts_in_tag, per_page)
          page_paths = []
          tag_pages = []
          (1..page_number).each do |current_page|
            # Collect all paths in the first pass and generate the basic page templates.
            page_name = current_page == 1 ? INDEXFILE : "page#{current_page}.html"
            page_paths.push page_name
            new_page = TagIndexPage.new(site, tag_path, page_name, tag, tag_layout, posts_in_tag, true)
            tag_pages.push new_page
          end

          (1..page_number).each do |current_page|
            # Generate the paginator content in the second pass.
            previous_link = current_page == 1 ? nil : page_paths[current_page - 2]
            next_link = current_page == page_number ? nil : page_paths[current_page]
            previous_page = current_page == 1 ? nil : (current_page - 1)
            next_page = current_page == page_number ? nil : (current_page + 1)
            tag_pages[current_page - 1].add_paginator_relations(current_page, per_page, page_number,
                                                                     previous_link, next_link, previous_page, next_page)
          end

          for page in tag_pages
            # Finally, add the new pages to the site in the third pass.
            site.pages << page
          end
        end

        Jekyll.logger.debug("Paginated tags", "Processed " + tags.size.to_s + " paginated tag index pages")
      end

      # Generate the non-paginated tag pages.
      #
      # site               - The Site object.
      # tag_base_path - String with the base path to the tag index pages.
      # tag_layout    - The name of the basic tag layout page.
      def generate_tags(site, tag_base_path, tag_layout)
        tags = sorted_tags site

        # Generate the pages
        for tag in tags
          posts_in_tag = site.tags[tag]
          tag_path = File.join(tag_base_path, CGI.escape(tag))

          site.pages << TagIndexPage.new(site, tag_path, INDEXFILE, tag, tag_layout, posts_in_tag, false)
        end

        Jekyll.logger.debug("Tags", "Processed " + tags.size.to_s + " tag index pages")
      end

    end
  end

  # Auto-generated page for a tag index.
  #
  # When pagination is enabled, contains a TagPager object as paginator. The posts in the
  # tag are always available as posts, the total number of those is always total_posts.
  class TagIndexPage < Page
    # Attributes for Liquid templates.
    ATTRIBUTES_FOR_LIQUID = %w(
      tag
      paginator
      posts
      total_posts
      content
      dir
      name
      path
      url
    )

    # Initialize a new tag index page.
    #
    # site              - The Site object.
    # dir               - Base directory for all tag pages.
    # page_name         - Name of this tag page (either 'index.html' or 'page#.html').
    # tag          - Current tag as a String.
    # tag_layout   - Name of the tag index page layout (must reside in the '_layouts' directory).
    # posts_in_tag - Array with full list of Posts in the current tag.
    # use_paginator     - Whether a TagPager object shall be instantiated as 'paginator'.
    def initialize(site, dir, page_name, tag, tag_layout, posts_in_tag, use_paginator)
      @site = site
      @base = site.source
      super(@site, @base, '', tag_layout)
      @dir = dir
      @name = page_name

      self.process @name

      @tag = tag
      @posts_in_tag = posts_in_tag
      @my_paginator = nil

      self.read_yaml(@base, tag_layout)
      self.data.merge!('title' => tag)
      if use_paginator
        @my_paginator = TagPager.new
        self.data.merge!('paginator' => @my_paginator)
      end
    end

    # Add relations of this page to other pages handled by a TagPager.
    #
    # Note that this method SHALL NOT be called if the tag pages are instantiated without pagination.
    # This method SHALL be called if the tag pages are instantiated with pagination.
    #
    # page               - Current page number.
    # per_page           - Posts per page.
    # total_pages        - Total number of pages.
    # previous_page      - Number of previous page or nil.
    # next_page          - Number of next page or nil.
    # previous_page_path - String with path to previous page or nil.
    # next_page_path     - String with path to next page or nil.
    def add_paginator_relations(page, per_page, total_pages, previous_page_path, next_page_path, previous_page, next_page)
      if @my_paginator
        @my_paginator.add_relations(page, per_page, total_pages,
                                    previous_page, next_page, previous_page_path, next_page_path)
        @my_paginator.add_posts(page, per_page, @posts_in_tag)
      else
        Jekyll.logger.warn("Tags", "add_relations does nothing since the tag page has been initialized without pagination")
      end
    end

    # Get the tag name this index page refers to
    #
    # Returns a string.
    def tag
      @tag
    end

    # Get the paginator object describing the current index page.
    #
    # Returns a TagPager object or nil.
    def paginator
      @my_paginator
    end

    # Get all Posts in this tag.
    #
    # Returns an Array of Posts.
    def posts
      @posts_in_tag
    end

    # Get the number of posts in this tag.
    #
    # Returns an Integer number of posts.
    def total_posts
      @posts_in_tag.size
    end
  end

  # Handle pagination of tag index pages.
  class TagPager
    attr_reader :page, :per_page, :posts, :total_posts, :total_pages,
                :previous_page, :previous_page_path, :next_page, :next_page_path

    # Static: Calculate the number of pages.
    #
    # all_posts - The Array of all Posts.
    # per_page  - The Integer of entries per page.
    #
    # Returns the Integer number of pages.
    def self.calculate_pages(all_posts, per_page)
      (all_posts.size.to_f / per_page.to_i).ceil
    end

    # Add numeric relationships of this page to other pages.
    #
    # page               - Current page number.
    # per_page           - Posts per page.
    # total_pages        - Total number of pages.
    # previous_page      - Number of previous page or nil.
    # next_page          - Number of next page or nil.
    # previous_page_path - String with path to previous page or nil.
    # next_page_path     - String with path to next page or nil.
    def add_relations(page, per_page, total_pages, previous_page, next_page, previous_page_path, next_page_path)
      @page = page
      @per_page = per_page
      @total_pages = total_pages
      @previous_page = previous_page
      @next_page = next_page
      @previous_page_path = previous_page_path
      @next_page_path = next_page_path
    end

    # Add page-specific post data.
    #
    # page              - Current page number.
    # per_page          - Posts per page.
    # posts_in_tag - Array with full list of Posts in the current tag.
    def add_posts(page, per_page, posts_in_tag)
      total_posts = posts_in_tag.size
      init = (page - 1) * per_page
      offset = (init + per_page - 1) >= total_posts ? total_posts : (init + per_page - 1)

      @total_posts = total_posts
      @posts = posts_in_tag[init..offset]
    end

    # Convert this TagPager's data to a Hash suitable for use by Liquid.
    #
    # Returns the Hash representation of this TagPager.
    def to_liquid
      {
          'page' => page,
          'per_page' => per_page,
          'posts' => posts,
          'total_posts' => total_posts,
          'total_pages' => total_pages,
          'previous_page' => previous_page,
          'previous_page_path' => previous_page_path,
          'next_page' => next_page,
          'next_page_path' => next_page_path
      }
    end
  end
end
