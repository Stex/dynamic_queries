#
# @attr [String] main_model_name
#   The class name of the main model this query is using
#
class DynamicQueries::Model
  unloadable if Rails.env.development?

  delegate :name, :table_name, :to_s, :human_attribute_name, :view_generated_sql, :to => :model_class

  def initialize(model_class)
    @klass = model_class
  end

  #
  # @return [String] the human model name
  #
  def human_name(options = {})
    model_class.human_name(options)
  end

  #
  # @return [Array<DynamicQueries::Column>]
  #   Information about the managed model's columns
  #
  def columns
    columns_mapping.values
  end

  #
  # @return [DynamicQueries::Column, NilClass]
  #   The column with the given name or +nil+ if there is no such column
  #
  def column_by_name(column_name)
    columns_mapping[column_name.to_s]
  end

  #
  # @return [Array<DynamicQueries::Association>]
  #   Information about the managed model's associations
  #
  # Note that only associations are returned which have a valid destination
  # and this destination is not member of the ignored models
  #
  def associations
    associations_mapping.values
  end

  #
  # @return [DynamicQueries::Association, NilClass]
  #   The association with the given name or +nil+ if not found
  #
  def association_by_name(association_name)
    associations_mapping[association_name.to_s]
  end

  #
  # @return [ActiveRecord::Base] The original model object
  #
  def model_class
    @klass
  end

  def dom_id(*args)
    (["model_proxy_#{to_s.underscore}"] + args).join('_')
  end

  private

  #
  # Maps column names to column proxy objects
  #
  def columns_mapping
    @columns_mapping ||= Hash[model_class.columns.reject {|c| ignored_columns.include?(c.name.to_s)}.map do |column|
      [column.name.to_s, DynamicQueries::Column.new(self, column)]
    end]
  end

  #
  # Maps association names to their association proxy instances
  #
  # @return [Hash] association_name => DynamicQueries::Association
  #
  def associations_mapping
    unless @associations_mapping
      @associations_mapping = {}
      model_class.reflect_on_all_associations.map do |association|
        proxy = DynamicQueries::Association.new(self, association)
        if DynamicQueries::DataCache.managed_model?(proxy.end_point)
          @associations_mapping[association.name.to_s] = proxy
        end
      end
    end
    @associations_mapping
  end

  #
  # @return [Array<String>] column names to be ignored by
  #   the plugin. They are set using
  #
  #     dynamic_queries_options :ignored_columns => []
  #
  #   in the model class.
  #   These values may either be Strings/Symbols representing the column name
  #   or regular expressions mapping to a whole bunch of columns at once.
  #
  def ignored_columns
    unless @ignored_column_names
      @ignored_column_names = []
      (DynamicQueries::DataCache.get_model_options(model_class)[:ignored_columns] || []).each do |name_or_regexp|
        if name_or_regexp.is_a?(Regexp)
          @ignored_column_names += model_class.columns.select {|c| c.name =~ name_or_regexp}.map(&:name)
        else
          if model_class.column_names.include?(name_or_regexp.to_s)
            @ignored_column_names << name_or_regexp.to_s
          end
        end
      end
      @ignored_column_names.uniq!
    end

    @ignored_column_names
  end
end