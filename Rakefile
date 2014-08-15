require "bundler/gem_tasks"
require 'json'
require 'coffee-script'

desc "Compiles the plugin's coffeescripts and stylesheets"
task :make do |t|
  #Compile the coffeescript file
  output_directory = './generators/dynamic_queries/templates/assets/js'

  Dir['app/assets/javascripts/*.coffee'].each do |file|
    compiled = CoffeeScript.compile File.read(file), :bare => true
    output_filename = File.basename(file).sub(File.extname(file), '.js')
    File.open(File.join(output_directory, output_filename), 'w') {|f| f.write(compiled)}
    # `coffee -l -c -o #{output_directory} #{file}`
  end
end
