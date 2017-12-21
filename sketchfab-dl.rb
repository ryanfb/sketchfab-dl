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

def login(browser)
  email, password = Netrc.read()['sketchfab.com']
  if(!email.nil?) && (!password.nil?)
    puts "Logging in as #{email}"
    browser.goto('https://sketchfab.com/login')
    puts 'Got page title: ' + browser.title
    browser.text_field(id: 'email').set email
    browser.text_field(id: 'password').set password
    browser.span(text: 'Log in').click
    browser.span(text: 'Log in').wait_while_present
    puts 'Login success'
    puts 'Got page title: ' + browser.title
    return true
  else
    puts 'Unable to get sketchfab.com username or password from .netrc'
    return false
  end
end

def download_model(browser, url)
  if url =~ /^https?:\/\/.*\.?sketchfab\.com\/models\/([[:xdigit:]]+)$/
    puts 'Downloading ' + url
    model_json = Net::HTTP.get(URI("https://api.sketchfab.com/v3/models/#{$1}"))
    output_filename = model_to_filename(JSON.parse(model_json))
    unless File.exist?(output_filename + '.json')
      puts "Writing metadata to: #{output_filename}.json"
      File.write(output_filename + '.json', model_json)
    end
    if File.exist?(output_filename + '.zip')
      puts "#{output_filename}.zip already exists, skipping"
    else
      begin
        browser.goto(url)
        puts 'Got page title: ' + browser.title
        if browser.span(text: 'Download').exists?
          zips_before = Dir.glob('*.zip')
          browser.span(text: 'Download').click
          browser.span(text: 'Download original').wait_until_present
          browser.span(text: 'Download original').click
          browser.span(text: 'Download original').wait_while_present
          begin
            print '.'
            sleep(1)
          end while (Dir.glob('*.crdownload').length > 0)
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
        sleep(1)
        retry
      end
    end
  else
    puts 'Unrecognized SketchFab model URL, skipping'
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

def model_to_filename(model_json)
  "#{I18n.transliterate(model_json['name']).downcase.gsub(/[^\w\s]/,'').tr(' ','-')}-#{model_json['uid']}"
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
  end
else
  puts "Login failure"
end

# document = Nokogiri::HTML(browser.html)
# puts document.search('title').xpath('text()')

browser.close
headless.destroy
