EXAMPLES = {
  "recommended_folder_structure" => {},
  "code_reloading"               => {},
  "dev_env"                      => {},
  "db_initialization"            => {},
  "migrations"                   => {},
  "fast_tests"                   => {},
  "pagination"                   => {},
  "sprocket_assets"              => {},
  "forms"                        => {},
  "urls"                         => {},
  "sidekiq"                      => {},
  "dim"                          => {},
}

class Cookbooks < Thor
  include Thor::Actions

  def self.source_root
    File.join(File.dirname(__FILE__))
  end

  EXAMPLES.each do |k, v|
    desc k, "#{k} example"
    define_method k do
      apply_directory_template(k)
      send "#{k}_adjust_files" if respond_to?("#{k}_adjust_files")
    end
  end

  desc "generate_all", "(!!!) (re)create all examples"
  def generate_all
    FileUtils.rm_rf "generated"
    EXAMPLES.keys.each do |k|
      send(k)
    end
  end


private
  def copy_stuff(example, files)
    files = [files] unless files.is_a?(Array)
    files.each do |file|
      copy_file("_templates/#{example}/#{file}", file, :force => true)
    end
  end

  def code_reloading_adjust_files
    copy_stuff(:code_reloading, "Readme.md")
  end

  def db_initialization_adjust_files
    copy_stuff(:db_initialization, "Readme.md")
  end

  def pagination_adjust_files
    copy_stuff(:pagination, "Readme.md")
    copy_stuff(:pagination, "lib/ext/will_paginate.rb")
    copy_stuff(:pagination, "config/environment.rb")

    template('_templates/pagination/app/models/user.rb', "app/models/user.rb", :force => true)
    template('_templates/pagination/app/controllers/my_app/frontend/pagination.rb', "app/controllers/my_app/frontend/pagination.rb", :force => true)
    copy_file('_templates/pagination/view/pagination/index.erb', "view/pagination/index.erb", :force => true)

    append_to_file 'Gemfile', :after => "gem 'class_loader'\n" do
      Util.unindent(%Q{
        ## will_paginate
        gem 'will_paginate'
        # active-record, simplified
        gem 'mini_record'
        gem 'sqlite3'
      })
    end

    empty_directory "db"
    run 'bundle install'
  end


  def sprocket_assets_adjust_files
    template('_templates/pagination/Readme.md', "Readme.md", :force => true)

  end

  def sidekiq_adjust_files
    template('_templates/sidekiq/Readme.md', "Readme.md", :force => true)
    template("_templates/sidekiq/sh/worker", "sh/worker")
    chmod "sh/worker", 0755
    template("_templates/sidekiq/app/workers/hard_worker.rb", "app/workers/hard_worker.rb")
    append_to_file 'Gemfile', :after => "gem 'class_loader'\n" do
      Util.unindent(%Q{

        ## A background worker
        gem 'sidekiq'
        # Sinatra for the sidekiq UI
        gem 'sinatra'
        gem 'slim'
      })
    end
    gsub_file 'config/environment.rb', /\(app\/lib app\/models app\/controllers\)/, "(app/lib app/models app/controllers app/workers)"
    insert_into_file "config.ru", :after => "require './app'" do
      Util.unindent(%Q{

        ## mount the sinatra UI
        require 'sidekiq/web'
        map "/sidekiq" do
          run Sidekiq::Web
        end
      })
    end
    run 'bundle install'
  end

  desc "apply_directory_template", "moves base app to a path"
  def apply_directory_template(app_name)
    self.destination_root = "generated/#{app_name}"
    directory '_project_base', destination_root
    inside('sh') do
      run('chmod +x *')
    end
  end
end

class Util
  def self.unindent(source)
    lines       = source.split("\n")
    min_spaces  = lines.map{|x| (x.index(/\S/)||9999)}.min
    short_lines = lines.map{|l| l[min_spaces..l.length]}
    short_lines.join("\n") + "\n"
  end
end