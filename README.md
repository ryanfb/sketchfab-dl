# sketchfab-dl

Command-line downloader for downloadable Sketchfab models. Supports downloading individual models or entire users.

## Requirements

* Ruby
* [Bundler](http://bundler.io/)
* A working install of [the requirements for the `headless` gem](https://github.com/leonid-shevtsov/headless) (Xvfb/XQuartz...)
* [ChromeDriver](https://sites.google.com/a/chromium.org/chromedriver/downloads) (`brew install chromedriver` on OS X)

## Usage

Add your Sketchfab login/password to your `~/.netrc` (which should be readable/writable only by the owner, which you can accomplish with `chmod 600 ~/.netrc`) like so:

    machine sketchfab.com
      login example@example.com
      password examplepassword

Then:

    bundle exec ./sketchfab-dl.rb sketchfaburl [sketchfaburl2 ...]

## FAQ

* I get the error: `Display socket is taken but lock file is missing - check the Headless troubleshooting guide`

[See this issue/comment on the `headless` gem which suggests running](https://github.com/leonid-shevtsov/headless/issues/80#issuecomment-278182878):

```
mkdir /tmp/.X11-unix
sudo chmod 1777 /tmp/.X11-unix
sudo chown root /tmp/.X11-unix/
```
