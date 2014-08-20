#
# This class represents a database query, created through the
# wizard process.
#
# Its table name is 'dynamic_queries' as it's less likely that
# this one will be used in a real application than 'query'
#
# @attr [String] name
#   The query's name
#
class DynamicQueries::Query < ActiveRecord::Base
  unloadable(DynamicQueries::Query) if Rails.env.development?

  #Set the table name to 'dynamic_queries' manually as otherwise Rails
  #would look for a table named 'dynamic_queries_query'
  self.table_name = 'dynamic_queries'

  #If a user class was given through the configuration,
  #add associations to the query's creator and updater
  if DynamicQueries::Configuration.user_class
    belongs_to :creator, :foreign_key => 'created_by', :class_name => DynamicQueries::Configuration.user_class
    belongs_to :updater, :foreign_key => 'updated_by', :class_name => DynamicQueries::Configuration.user_class
  end

  include DynamicQueries::Concerns::Associations
  include DynamicQueries::Concerns::Models
  include DynamicQueries::Concerns::Columns

  include DynamicQueries::DatabaseHelpers

  TIMEOUT_MS = 250

  #----------------------------------------------------------------
  #                        Validations
  #----------------------------------------------------------------

  validates_presence_of  :name
  validates_presence_of  :main_model_name
  validates_inclusion_of :main_model_name, :in => DynamicQueries::DataCache.models.keys

  #The models which are part of the query
  serialize :model_names_array, Array

  #Associations between the models (join chains)
  serialize :associations_hash, Hash

  #Positions of the model boxes during query creation (pure UI, no further use)
  serialize :model_positions_hash, Hash

  #Columns to be used in the query. This array contains the serialized versions,
  #the columns are manipulated through {DynamicQueries::QueryColumn}
  serialize :columns_array, Array

  # The query conditions has hash, mapping clause types to tokens
  # Tokens may either be condition identifiers, connectors or brackets.
  # Clause types here are currently 'WHERE' and 'HAVING'
  serialize :conditions_hash, Hash

  #----------------------------------------------------------------
  #                     ActiveRecord Callbacks
  #----------------------------------------------------------------

  before_save :remove_abandoned_columns
  before_save :remove_abandoned_associations
  before_save :remove_abandoned_conditions
  before_save :save_query_columns

  def execute(options = {})
    DynamicQueries::ResultSet.new(self, options)
  end

  def to_sql(options = {})
    main_model.view_generated_sql(:all, to_finder_hash(options))
  end

  #
  # @return [Boolean] +true+ if the query produces valid SQL
  #
  def valid_sql?
    !sql_error?(to_sql)
  end

  def sql_error
    thrown_sql_error(to_sql).first
  end

  def timeout?
    thrown_sql_error(to_sql).last == :timeout
  end

  #
  # @return [Boolean] +true+ if the given step is available
  #   during query creation. This is the case if the query
  #   already has the necessary data to work on in the step.
  #
  def step_available?(step_name)
    case step_name.to_s
      when 'models', 'edit', 'new' then true
      when 'associations'          then main_model && models.any?
      when 'columns'               then step_available?('associations')
      when 'query_options'         then step_available?('columns') && columns.any?
      else false
    end
  end

  #
  # @return [Boolean] +true+ if the query can be executed. This is the case if:
  #
  #   1. It has at least one select column
  #
  def executable?
    select_columns.any?
  end

  #
  # @return [Symbol]
  #   The step to be used when the query edit process is started.
  #   This is currently the last available step as it's most likely that
  #   it will change again.
  #
  def edit_step
    [:edit, :associations, :columns, :query_options].select {|s| step_available?(s)}.last
  end

  private

  def to_finder_hash(options = {})
    hash      = {}
    variables = (options[:variables] || {}).stringify_keys

    hash[:joins]    = joins_string if joins?

    #Handle custom select values
    hash[:select]   = options[:select]
    hash[:select] ||= select_column_names.join(', ') if select_columns.any?

    #Handle custom order by options.
    hash[:order]    = order_by_column_names.join(', ')
    hash[:order]    = build_order_string(options[:order]) if options[:order]
    hash[:order]    = nil if hash[:order].blank?

    hash[:group]    = group_by_column_names.join(', ') if group_by_columns.any?

    #Handle per_page / limits
    hash[:limit]    = options[:limit] || options[:per_page]
    hash[:offset]   = options[:offset]
    hash[:offset] ||= (options[:page].to_i - 1) * hash[:limit] if options[:page] && hash[:limit]

    #Handle conditions (WHERE and HAVING)
    if where_conditions.any?
      hash[:conditions] = [where_conditions.to_sql] + where_conditions.condition_values(variables)
    end
    if having_conditions.any?
      hash[:having] = [having_conditions.to_sql] + having_conditions.condition_values(variables)
    end

    hash
  end

  def build_order_string(order_options)
    order_options.map do |column, direction|
      "#{column} #{direction.upcase}"
    end.join(', ')
  end

  #
  # Updates the serialized columns array before the query is saved
  #
  def save_query_columns
    self.columns_array = columns.map(&:to_h)
  end

  #
  # Looks up the given model in the DataCache
  #
  # @param [String, DynamicQueries::Model] model the model to be looked up
  #
  # @return [DynamicQueries::Model]
  #
  def model_proxy(model)
    return model if model.is_a?(DynamicQueries::Model)
    DynamicQueries::DataCache.models[model.to_s]
  end

  #
  # ActiveRecord :before_save callback
  #
  # Removes associations to models which are no longer part of the association chain.
  # This is mainly needed if a model is removed in the first step
  #
  def remove_abandoned_associations
    associations.values.flatten.each do |association|
      unless models.include?(association.end_point)
        remove_association(association.model, association.name)
      end
    end
  end

  #
  # ActiveRecord :before_save callback
  #
  # This method removes column from the query if their model
  # is no longer part of the query either.
  #
  def remove_abandoned_columns
    columns.select {|c| !model_names.include?(c.model.to_s) }.each do |column|
      remove_column(column.identifier)
    end
  end

  #
  # ActiveRecord :before_save callback
  #
  # Deletes the HAVING or WHERE conditions (from +conditions_hash+)
  # if either one of the used query columns does no longer exist or
  # the condition was deleted from it.
  #
  # This callback have to run after abandoned columns / associations were
  # deleted as otherwise not all removed columns might be noticed.
  #
  def remove_abandoned_conditions
    reset_done = false
    unless where_conditions.valid?
      self.conditions_hash[:where]  = []
      reset_done                    = true
    end

    unless having_conditions.valid?
      self.conditions_hash[:having] = []
      reset_done                    = true
    end

    @conditions = nil if reset_done
  end
end