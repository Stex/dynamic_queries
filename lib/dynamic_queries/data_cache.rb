#
# This class analyzes the rails application it is part of
# and keeps hold of its findings.
#
class DynamicQueries::DataCache
  include Singleton
  unloadable if Rails.env.development?

  #
  # Loads all models in the application. They are cached as models
  # usually don't simply appear in a running application.
  #
  def models
    unless @models
      #Load all tables from default application database
      tables = ActiveRecord::Base.connection.tables

      #try to constantize them. If tables exist which do not match a known class, they will be removed
      constantized_tables = tables.collect {|t| t.classify.constantize rescue nil }.compact

      #Filter out classes which do not inherit from ActiveRecord::Base.
      #This is not a common case, but who knows.
      #We might not have all models yet, e.g. single table inheritances are not covered
      #when we only take models which have own tables in the database. This also
      #happens for models which use tables in different databases or just custom table names.
      models_from_tables = constantized_tables.select {|c| c < ActiveRecord::Base}

      #Get all files which are inside a "models" directory throughout the application.
      #This will fetch app/models as well as /models inside a plugin
      #Sometimes these classes are inside of modules, so a simple File.basename wouldn't work.
      #Instead, a regular expression for /models/** is done to get the whole constant name.
      class_names_from_files = Dir['**/models/**/*.rb'].collect {|m| (m.scan /models\/(.*)\.rb/).first.first }

      #Constantize these files to see if they are actually existing as global constants.
      #In this step the array might still contain non-ActiveRecord classes
      classes_from_files = class_names_from_files.collect {|cn| cn.camelize.constantize rescue nil }.compact

      #Filter out classes which do not inherit from ActiveRecord::Base.
      #These might be mailer classes or simply classes which were put into app/models instead
      #of /lib to be auto-loaded.
      models_from_files = classes_from_files.select {|c| c < ActiveRecord::Base}

      #Use found models from tables + files to get all available ones
      #Also delete duplicates
      classes = (models_from_tables + models_from_files).uniq.sort {|x,y| x.to_s <=> y.to_s}

      #Remove excluded classes
      classes -= DynamicQueries::Configuration.excluded_models

      #Remove the included model
      classes -= [DynamicQueries::Query]

      #Sort Models by name for later use
      classes.sort! {|x,y| x.to_s <=> y.to_s}

      @models = Hash[classes.map {|c| [c.to_s, DynamicQueries::Model.new(c)]}]
    end

    @models
  end

  #
  # @return [DynamicQueries::Model] the model proxy for the given model name
  #
  def model(model_name)
    models[model_name.to_s]
  end

  #
  # @return [Boolean] +true+ if the given model is valid and not ignored
  #
  def managed_model?(model)
    models.keys.include?(model.to_s.classify)
  end

  #
  # Sets options for one given model. This comes from the
  # dynamic_queries_options method in ActiveRecord::Base
  #
  def set_model_options(model, options)
    model_options[model.to_s] = options
  end

  #
  # @see #set_model_options
  #
  def get_model_options(model)
    model_options[model.to_s] || {}
  end

  #
  # Helper method to log an erroneous connection. It is called DynamicQueries::Association#end_point
  #
  def log_erroneous_association(association, message)
    Rails.logger.error "\n\n   [DynamicQueries] Found the erroneous association '#{association.name}' in model '#{association.model.name}'. Internal message:\n                    #{message}\n\n"
  end

  private

  #
  # Instance cache for model options
  #
  def model_options
    @model_options ||= {}
  end

  #
  # Forward unknown methods to the instance
  #
  def self.method_missing(method, *args)
    self.instance.send(method, *args)
  end
end