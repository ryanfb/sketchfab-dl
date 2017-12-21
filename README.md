# sketchfab-dl

Command-line downloader for downloadable Sketchfab models. Supports downloading individual models or entire users.

## Requirements

* Ruby
* [Bundler](http://bundler.io/)
* A working install of [the requirements for the `headless` gem](https://github.com/leonid-shevtsov/headless) (Xvfb/XQuartz...)
* [ChromeDriver](https://sites.google.com/a/chromium.org/chromedriver/downloads) (`brew install chromedriver` on OS X)

## Usage

    bundle exec ./sketchfab-dl.rb sketchfaburl [sketchfaburl2 ...]

## FAQ

* I get the error: `Display socket is taken but lock file is missing - check the Headless troubleshooting guide`

See this issue/comment on the `headless` gem: <https://github.com/leonid-shevtsov/headless/issues/80#issuecomment-278182878>
