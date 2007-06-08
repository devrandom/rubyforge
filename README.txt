== Synopsis

  rubyforge [options]* mode [mode_args]*

== Description

A simplistic script which automates a limited set of rubyforge operations 

* Run 'rubyforge help' for complete usage.
* Setup: For first time users AND upgrades to 0.4.0:
  * rubyforge setup
  * edit ~/.rubyforge/user-config.yml
  * rubyforge config
* Don't forget to login!  logging in will store a cookie in your
  .rubyforge directory which expires after a time.  always run the
  login command before any operation that requires authentication,
  such as uploading a package.
