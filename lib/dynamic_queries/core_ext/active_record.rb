module DynamicQueries::CoreExt::ActiveRecord
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods

    #
    # Helper method to set model specific options for the plugin
    #
    # @option options [Array<String, Symbol, RegExp>] :ignored_columns
    #   Columns names to be ignored by the plugin. This means, they will not
    #   appear in table overviews and cannot be used in created queries.
    #
    #   If a regular expression is given as an array item, all column names
    #   matching this regexp will be ignored. With this, you don't have
    #   to add e.g. paperclip columns by yourself.
    #
    def dynamic_queries_options(options = {})
      DynamicQueries::DataCache.set_model_options(self, options)
    end

    #
    # Does basically the same that .all(*args) does,
    # but it will return the generated SQL code.
    #
    def view_generated_sql(*args)
      options = args.extract_options!
      validate_find_options(options)
      set_readonly_option!(options)
      construct_finder_sql(options)
    end
  end

end

ActiveRecord::Base.class_eval do
  include DynamicQueries::CoreExt::ActiveRecord
end