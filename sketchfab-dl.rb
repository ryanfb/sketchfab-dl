#!/usr/bin/env ruby

require 'watir'
require 'nokogiri'
require 'headless'
require 'netrc'
require 'pp'
require 'net/http'
require 'json'
require 'fileutils'
require 'i18n'
I18n.config.available_locales = :en

DEFAULT_SLEEP = 5

def login(browser)
  if File.exist?('.cookies')
    puts 'Loading cookies from .cookies file'
    browser.goto('https://sketchfab.com/')
    browser.cookies.load '.cookies'
    return true
  else
    email, password = Netrc.read()['sketchfab.com']
    if(!email.nil?) && (!password.nil?)
      puts "Logging in as #{email}"
      browser.goto('https://sketchfab.com/login')
      puts 'Got page title: ' + browser.title
      browser.text_field(id: 'email').set email
      browser.text_field(id: 'password').set password
      browser.button(type: 'submit').click
      # browser.span(text: 'Log in').click
      browser.span(text: 'Log in').wait_while_present
      browser.h2(text: 'My Settings').wait_until(&:present?)
      puts 'Login success'
      puts 'Got page title: ' + browser.title
      puts 'Saving cookies to .cookies file:'
      puts browser.cookies.to_a.to_s
      browser.cookies.save '.cookies'
      return true
    else
      puts 'Unable to get sketchfab.com username or password from .netrc'
      return false
    end
  end
end

def download_model(browser, url)
  if url =~ /^https?:\/\/.*\.?sketchfab\.com\/models\/([[:xdigit:]]+)$/
    puts 'Downloading ' + url
    browser.goto(url)
    puts 'Got page title: ' + browser.title
    nokogiri_document = Nokogiri::HTML(browser.html)
    model_name = nokogiri_document.css('span.model-name__label')[0].text
    # output_filename = model_to_filename(JSON.parse(model_json))
    output_filename = model_to_filename(model_name, $1)
    unless File.exist?(output_filename + '.json')
      puts "Fetching JSON metadata"
      model_json = Net::HTTP.get(URI("https://api.sketchfab.com/v3/models/#{$1}"))
      if JSON.parse(model_json)["detail"] == "Enhance your calm."
        puts "Hit Sketchfab API rate limit...try re-downloading later."
      else
        puts "Writing metadata to: #{output_filename}.json"
        File.write(output_filename + '.json', model_json)
      end
    end
    if File.exist?(output_filename + '.zip')
      puts "#{output_filename}.zip already exists, skipping"
    else
      begin
        if browser.span(text: 'Download').exists?
          zips_before = Dir.glob('*.zip')
          crdownload_before = Dir.glob('*.crdownload')
          browser.span(text: 'Download').click
          puts "Initial download button clicked, waiting for download dialogue"
          browser.button(text: 'Download', class: 'button-source').wait_until(&:present?)
          browser.button(text: 'Download', class: 'button-source').click
          print "Download dialogue download button clicked, waiting for Chrome download to finish"
          until Dir.glob('*.crdownload') != crdownload_before
            sleep(1.0/100.0)
          end
          until Dir.glob('*.crdownload') == crdownload_before
            print '.'
            sleep(1)
          end
          puts 'download finished.'
          downloaded_filename = (Dir.glob('*.zip') - zips_before).first
          if downloaded_filename.nil?
            raise 'Got an empty download, retrying...'
          else
            FileUtils.mv downloaded_filename, output_filename + '.zip', :verbose => true
          end
        else
          puts 'Model not available for download, skipping'
        end
      rescue Exception => e
        puts e.message
        sleep(DEFAULT_SLEEP)
        browser.goto(url)
        retry
      end
    end
  else
    puts 'Unrecognized Sketchfab model URL, skipping'
  end
end

def download_user(browser, username)
  puts 'Downloading all downloadable models for user: ' + username
  page = 1
  models_url = "https://api.sketchfab.com/v3/models?user=#{username}&downloadable=true"
  begin
    puts "Downloading models page: #{page}"
    models_json = JSON.parse(Net::HTTP.get(URI(models_url)))
    puts "About to fetch #{models_json["results"].length} models"
    models_json["results"].each do |model|
      download_model(browser, model['viewerUrl'])
      sleep(DEFAULT_SLEEP)
    end
    if models_json.has_key?("next")
      models_url = models_json["next"]
    else
      models_url = nil
    end
    page += 1
  end while models_url
end

def sketchfab_download(browser, url)
  if url.include?('/models/')
    download_model(browser, url)
  elsif url =~ /^https?:\/\/.*\.?sketchfab\.com\/([^\/]+)/
    download_user(browser, $1)
  end
end

def model_to_filename(name, uid)

  "#{I18n.transliterate(name).downcase.gsub(/[^\w\s]/,'').tr(' ','-')}-#{uid}"
end

headless = Headless.new
headless.start

prefs = {
	'download' => {
		'default_directory' => Dir.pwd,
		'prompt_for_download' => false,
		'directory_upgrade' => true,
	},
	'profile' => {
		'default_content_settings' => {'multiple-automatic-downloads' => 1}, #for chrome ~42
		'default_content_setting_values' => {'automatic_downloads' => 1}, #for chrome 46
	}
}
browser = Watir::Browser.new :chrome, options: {prefs: prefs}

if login(browser)
  ARGV.each do |sketchfab_url|
    sketchfab_download(browser, sketchfab_url)
    sleep(DEFAULT_SLEEP)
  end
else
  puts "Login failure"
end

browser.close
headless.destroy
