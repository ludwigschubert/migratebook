require 'rubygems'
require 'mysql'
require 'anemone'
require 'pry'
require 'active_support'

class GuestbookEntry
	
	attr_accessor :name, :url, :comment, :date
	
	def self.from_xml xml
		entry = GuestbookEntry.new
		entry.name    = xml.css('td.tab').first.css('b').first.content
		entry.url     = xml.css('td.tab').first.css('a').last.content rescue nil
		comment_lines = xml.css('td.tab').last.content.lines.to_a rescue nil
		entry.comment = comment_lines[3..-1].join(" ") rescue nil
		entry.date    = DateTime.parse(xml.css('td.tab').last.at_css('div').content[16..-1]) rescue nil
		entry
	end
	
	def valid?
		name && comment && date
	end
	
end

Anemone.crawl("http://www.flf-book.de/Benutzer/ironrose.0.htm") do |anemone|
	anemone.focus_crawl do |page|
		page.links.select do |link|
			link.to_s.start_with? 'http://www.flf-book.de/Benutzer/ironrose.'
		end
	end
	
	xml_entries = []
	anemone.on_every_page do |page|
			xml_entries += page.doc.css('tr.tab')
	end
	
	anemone.after_crawl do
		entries = xml_entries.map do |xml_entry|
			GuestbookEntry.from_xml(xml_entry)
		end.select do |entry|
			entry.valid?
		end
		
		puts entries.count
		
		db = Mysql.new('wp175.webpack.hosteurope.de', 'dbu1143784', 'cubicmapping', 'db1143784-wordpress')
		
		begin
			entries.each do |entry|
				insert_new_user = db.prepare "INSERT INTO wordpresswp_comments (comment_post_ID, comment_author, comment_author_url, comment_content, comment_date, comment_date_gmt) VALUES (?, ? ,?, ?, ?, ?)"
				insert_new_user.execute "628", entry.name, "#{entry.url}", entry.comment, entry.date.to_s, entry.date.to_s
				insert_new_user.close
			end
		ensure
			db.close
		end
		
	end
end