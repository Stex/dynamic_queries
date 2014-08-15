class DynamicQueriesGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.file File.join('assets', 'js', 'dynamic_queries.js'), File.join('public', 'javascripts', 'dynamic_queries.js')
      m.file File.join('assets', 'css', 'dynamic_queries.css'), File.join('public', 'stylesheets', 'dynamic_queries.css')
    end
  end

  protected

  def banner
    "Usage: #{$0} rjs_helpers assets"
  end
end
