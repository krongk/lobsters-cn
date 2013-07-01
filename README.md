###This is a Chinese version of Lobsters. 

The original git source: [https://github.com/jcs/lobsters](https://github.com/jcs/lobsters)
And the living demo: [https://lobste.rs](https://lobste.rs). 

####Initial setup

* Install Ruby 1.9.3 or higher.

* Checkout the lobsters git tree from Github

         $ git clone git@github.com:krongk/lobsters-cn.git
         $ cd lobsters-cn
         lobsters-cn$ 

* Run Bundler to install/bundle gems needed by the project:

         lobsters-cn$ bundle

* Update `file_to_copy`, and copy or overwrite to each directories:

          config/database.yml
          config/application.yml
          config/initializers/secret_token.rb
          config/initializers/domain.rb
          db/seeds.rb

* Load the schema into the new database:

					lobsters-cn$ rake db:create
          lobsters-cn$ rake db:schema:load

* initialize data:

          lobsters-cn$ rake db:seed

* (Optional, only needed for the search engine) Install Sphinx.  Build Sphinx
config and start server:

          lobsters-cn$ rake thinking_sphinx:rebuild

* Run the Rails server:

          lobsters-cn$ rails server
