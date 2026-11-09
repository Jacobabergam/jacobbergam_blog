#!/usr/bin/env ruby
# Refreshes _data/recently_read.yml from Goodreads' public shelf widget.
#
# Goodreads retired the shelf RSS feeds (/review/list_rss/<id>) in late
# October 2026; they now return 404, and the HTML shelf pages need a login.
# The embeddable shelf widget (/review/custom_widget/<id>) is still public.
# It returns at most 100 books (most recently read first) and carries no read
# dates, so this script merges it into the existing data file instead of
# replacing it:
#
# - a book already in the file keeps its year_read (and gains an author or
#   cover if the file lacked one);
# - a book the file has never seen gets the current year as year_read;
# - books older than the widget's 100 stay as they are in the file.
#
# If a year comes out wrong (e.g. a book marked read on Jan 1 that you
# finished on Dec 31), edit year_read in _data/recently_read.yml by hand; the
# next run keeps your edit.
#
# Usage: ruby scripts/fetch_goodreads.rb
# Optional: GOODREADS_USER_ID=123456 ruby scripts/fetch_goodreads.rb

require "net/http"
require "uri"
require "yaml"
require "cgi"
require "date"
require "fileutils"

GOODREADS_USER_ID = (ENV["GOODREADS_USER_ID"] || "").strip.empty? ? "114910493" : ENV["GOODREADS_USER_ID"].strip
WIDGET_MAX = 100
OUT_PATH = File.expand_path("../_data/recently_read.yml", __dir__)

def widget_uri
  params = {
    "shelf" => "read",
    "sort" => "date_read",
    "order" => "d",
    "num_books" => WIDGET_MAX,
    "show_title" => 1,
    "show_author" => 1,
    "show_cover" => 1,
    "widget_id" => "blog"
  }
  query = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
  URI("https://www.goodreads.com/review/custom_widget/#{GOODREADS_USER_ID}?#{query}")
end

def fetch(uri, attempts: 3)
  attempts.times do |i|
    begin
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) do |http|
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "Mozilla/5.0 (compatible; jacobbergam-blog-reading-list)"
        http.request(req)
      end
      return res.body if res.is_a?(Net::HTTPSuccess)

      warn "Goodreads widget: HTTP #{res.code} (attempt #{i + 1}/#{attempts})"
    rescue StandardError => e
      warn "Goodreads widget: #{e.class}: #{e.message} (attempt #{i + 1}/#{attempts})"
    end
    sleep(10 * (i + 1)) if i < attempts - 1
  end
  abort "Failed to fetch the Goodreads shelf widget."
end

# The widget is JavaScript: `var widget_code = '<html…>'`. Pull the string out
# and undo the JS escaping so it reads as plain HTML.
def widget_html(js)
  m = js.match(/var widget_code = '(.*?)';?\s*\n\s*var widget_div/m)
  abort "Goodreads widget: unexpected response (no widget_code)." unless m

  m[1].gsub("\\n", "\n").gsub(/\\(["'\/\\])/, '\1')
end

def review_id(link)
  link.to_s[%r{/review/show/(\d+)}, 1]
end

# Goodreads covers carry a size suffix (._SX50_, ._SY75_); drop it for full res.
def full_res(cover)
  return nil if cover.to_s.empty? || cover.include?("nophoto")

  cover.gsub(/\._S[XY]\d+_/, "").gsub(/S[XY]\d+_\.(jpg|jpeg|png)/i, '.\1')
end

def parse_widget(html)
  html.split(/<div class="gr_custom_each_container_[^"]*">/)[1..-1].to_a.map do |chunk|
    title_m = chunk.match(/<div class="gr_custom_title_[^"]*">\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>/m)
    next nil unless title_m

    link = CGI.unescapeHTML(title_m[1]).sub(/\?.*\z/, "")
    author_m = chunk.match(/<div class="gr_custom_author_[^"]*">.*?<a[^>]*>(.*?)<\/a>/m)
    cover_m = chunk.match(/<img[^>]*src="([^"]+)"/)
    {
      "title" => CGI.unescapeHTML(title_m[2].strip),
      "author" => author_m ? CGI.unescapeHTML(author_m[1].strip) : nil,
      "link" => link,
      "cover_url" => full_res(cover_m && cover_m[1])
    }.reject { |_, v| v.nil? || v.to_s.empty? }
  end.compact
end

def load_existing
  return [] unless File.exist?(OUT_PATH)

  data = YAML.safe_load(File.read(OUT_PATH)) || {}
  data["books"] || []
end

def merge(widget_books, existing, this_year)
  by_id = {}
  existing.each { |b| by_id[review_id(b["link"])] ||= b }

  seen = {}
  merged = widget_books.map do |w|
    id = review_id(w["link"])
    seen[id] = true
    old = by_id[id]
    if old
      # Keep the stored entry (its link and year); fill in what it lacked.
      old.merge(w.reject { |k, _| k == "link" }) { |_, old_v, new_v| old_v.to_s.empty? ? new_v : old_v }
    else
      w.merge("year_read" => this_year)
    end
  end

  older = existing.reject { |b| seen[review_id(b["link"])] }
  merged.concat(older)

  # Newest year first; within a year keep widget order (most recently read
  # first), then the file's order. sort_by is not stable, so use the index.
  sorted = merged.each_with_index.sort_by { |b, i| [-(b["year_read"] || 0), i] }.map(&:first)
  sorted.map { |b| KEY_ORDER.each_with_object({}) { |k, h| h[k] = b[k] unless b[k].nil? }.merge(b) }
end

KEY_ORDER = %w[title author link cover_url year_read].freeze

def main
  html = widget_html(fetch(widget_uri))
  widget_books = parse_widget(html)
  abort "Goodreads widget returned no books; leaving #{OUT_PATH} untouched." if widget_books.empty?

  existing = load_existing
  books = merge(widget_books, existing, Date.today.year)
  added = books.size - existing.size

  FileUtils.mkdir_p(File.dirname(OUT_PATH))
  File.write(OUT_PATH, { "books" => books }.to_yaml)
  puts "Widget returned #{widget_books.size} books; #{added} new. Wrote #{books.size} books to #{OUT_PATH}"
end

main if $PROGRAM_NAME == __FILE__
