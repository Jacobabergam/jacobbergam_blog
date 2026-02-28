#!/usr/bin/env ruby
# Fetches your Goodreads "read" shelf via RSS and writes _data/recently_read.yml
# for Jekyll. Run before `jekyll build` to refresh the list.
#
# Usage: ruby scripts/fetch_goodreads.rb
# Optional: GOODREADS_USER_ID=123456 ruby scripts/fetch_goodreads.rb
# Optional: GOODREADS_API_KEY=key (if RSS requires it)

require "net/http"
require "rexml/document"
require "yaml"
require "cgi"
require "fileutils"

GOODREADS_USER_ID = ENV["GOODREADS_USER_ID"] || "114910493"
GOODREADS_API_KEY = ENV["GOODREADS_API_KEY"]
PER_PAGE = 24
SHELF = "read"
SORT = "date_read"

def build_rss_uri
  params = { "shelf" => SHELF, "sort" => SORT, "per_page" => PER_PAGE }
  params["key"] = GOODREADS_API_KEY if GOODREADS_API_KEY && !GOODREADS_API_KEY.empty?
  query = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
  URI("https://www.goodreads.com/review/list_rss/#{GOODREADS_USER_ID}?#{query}")
end

def fetch_rss(uri)
  Net::HTTP.get(uri)
rescue StandardError => e
  warn "Failed to fetch Goodreads RSS: #{e.message}"
  exit 1
end

def text_at(node, xpath)
  n = node.elements[xpath]
  n&.text&.strip
end

def parse_item(item_el)
  title = text_at(item_el, "title")
  link  = text_at(item_el, "link")
  return nil if title.to_s.empty?

  # Goodreads RSS often has custom elements for book cover and author
  cover = text_at(item_el, "book_medium_image_url") ||
          text_at(item_el, "book_small_image_url") ||
          text_at(item_el, "book_image_url")
  author_el = item_el.elements["author"]
  author = author_el ? text_at(author_el, "name") : nil

  # Fallback: parse description for cover img and "by Author"
  if (author.to_s.empty? || cover.to_s.empty?) && item_el.elements["description"]
    desc = item_el.elements["description"].text.to_s
    cover = $1 if cover.to_s.empty? && desc =~ /<img[^>]+src="([^"]+)"/i
    author = $1.strip if author.to_s.empty? && desc =~ /by\s+([^<\n]+)/i
  end

  # Strip Goodreads size suffix (._SX98_, ._SY160_, etc.) so we get full-res images (less blurry)
  cover = cover.gsub(/\._S[XY]\d+_/, "") if cover && cover.match?(/\._S[XY]\d+_/i)

  {
    "title" => title,
    "author" => author.to_s.empty? ? nil : author,
    "link" => link,
    "cover_url" => cover.to_s.empty? ? nil : cover,
  }.compact
end

def parse_rss(xml_str)
  doc = REXML::Document.new(xml_str)
  items = []
  REXML::XPath.each(doc, "//item") do |item_el|
    entry = parse_item(item_el)
    items << entry if entry
  end
  items
end

def main
  uri = build_rss_uri
  xml = fetch_rss(uri)
  books = parse_rss(xml)

  data_dir = File.join(__dir__, "..", "_data")
  FileUtils.mkdir_p(data_dir)
  out_path = File.join(data_dir, "recently_read.yml")

  File.write(out_path, { "books" => books }.to_yaml)
  puts "Wrote #{books.size} books to #{out_path}"
end

main
