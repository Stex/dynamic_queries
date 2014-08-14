require 'securerandom'

#
# Helper class representing a single chosen column within
# the dynamic query.
#
class DynamicQueries::QueryColumn
  unloadable if Rails.env.development?

  delegate :name, :localized_name, :type, :name_with_table, :to => :column

  def initialize(query, column_hash = {})
    @query       = query
    @column_hash = column_hash

    @position           = column_hash[:position]
    @custom_name        = column_hash[:custom_name]
    @show_column        = column_hash[:show_column]
    @order_by           = column_hash[:order_by]
    @group_by           = column_hash[:group_by]
    @order_by_position  = column_hash[:order_by_position] || @position
    @select_position    = column_hash[:select_position] || @position
    @identifier         = column_hash[:identifier]
    @aggregate_function = column_hash[:aggregate_function]
  end

  def dom_id(*args)
    column.dom_id('query_column', identifier, *args)
  end

  def set_option(option_name, new_value)
    send("#{option_name}=", new_value)
  end

  def query
    @query
  end

  #
  # @return [DynamicQueries::Model]
  #   The model this column belongs to
  #
  def model
    DynamicQueries::DataCache.model @column_hash[:model_name]
  end

  #
  # @return [DynamicQueries::Column]
  #   The database column this query column belongs to
  #
  def column
    model.column_by_name(@column_hash[:column_name])
  end

  def custom_name
    @custom_name
  end

  #
  # Sets a new custom name for this column
  #
  def custom_name=(new_custom_name)
    @custom_name = new_custom_name
  end

  def custom_name?
    custom_name.present?
  end

  #
  # @return [String] Name for this column to be displayed e.g. as table header.
  #   Note that it is not used in the query itself as it might not be unique.
  #
  def output_name
    return custom_name if custom_name?

    if aggregate_function?
      applied_aggregate_function_string
    else
      name_with_table
    end
  end

  #
  # @return [String] the column name to be used in the WHERE or HAVING clause
  #
  def condition_clause_identifier
    if aggregate_function?
      applied_aggregate_function_string
    else
      name_with_table
    end
  end

  #
  # @return [String] Identifier for this column to be used
  #   in the SQL query. If the column is part of the select clause,
  #   we may use its identifier, otherwise, we have to use its table and column name.
  #
  def sql_identifier
    show? ? identifier : name_with_table
  end

  #----------------------------------------------------------------
  #                          ORDER BY
  #----------------------------------------------------------------

  def order_by
    @order_by
  end

  def order_by=(new_value)
    @order_by = new_value if ['', 'asc', 'desc'].include?(new_value.to_s.downcase)
  end

  def order_by?
    @order_by.present?
  end

  #
  # @return [String]
  #   String to be used in the ORDER BY clause of the query.
  #
  # If the column is also used in the select clause, we can safely use
  # its alias (the identifier).
  # Otherwise, we have to use the table and column name, even if it might
  # not be unique any more in the query
  #
  def order_by_string
    show? ? "#{identifier} #{order_by}" : "#{name_with_table} #{order_by}"
  end

  def order_by_position
    @order_by_position
  end

  def order_by_position=(new_position)
    @order_by_position = new_position.to_i
  end

  #----------------------------------------------------------------
  #                          GROUP BY
  #----------------------------------------------------------------

  def group_by?
    !!@group_by
  end

  def group_by=(new_value)
    @group_by = bool_value(new_value)
  end

  #----------------------------------------------------------------
  #                           SELECT
  #----------------------------------------------------------------

  def show?
    !!@show_column
  end

  def show=(new_value)
    @show_column = bool_value(new_value)
  end

  #
  # @return [String]
  #   String to be used in the select clause of the query.
  #   The column is automatically alias'd with its identifier to receive
  #   unique output.
  #
  def select_string
    if aggregate_function?
      "#{applied_aggregate_function_string} AS #{identifier}"
    else
      "#{column.name_with_table} AS #{identifier}"
    end
  end

  def select_position
    @select_position
  end

  def select_position=(new_position)
    @select_position = new_position.to_i
  end

  #----------------------------------------------------------------
  #                            Positions
  #----------------------------------------------------------------

  def position
    @position
  end

  def position=(new_position)
    @position = new_position.to_i
  end

  #
  # Sets a new position for a part of the clause
  #
  # @example Set a new ORDER BY position
  #   set_position('order_by', 5)
  #
  def set_position(position_type, new_position)
    send("#{position_type}_position=", new_position.to_i)
  end

  #----------------------------------------------------------------
  #                         Scalar Functions                  TODO?
  #----------------------------------------------------------------

  #----------------------------------------------------------------
  #                       Aggregate Functions
  #----------------------------------------------------------------

  def aggregate_function?
    @aggregate_function.present? && available_aggregate_functions.include?(@aggregate_function.to_sym)
  end

  def aggregate_function
    @aggregate_function.to_s
  end

  def aggregate_function=(new_value)
    @aggregate_function = new_value
  end

  def available_aggregate_functions
    functions = [:count, :distinct_count, :min, :max]
    functions += [:sum, :avg] if column.klass < Numeric
    functions
  end

  def available_aggregate_function_options
    [['', '']] + available_aggregate_functions.map do |function_name|
      [I18n.t(function_name, :scope => 'dynamic_queries.aggregate_functions'), function_name.to_s]
    end
  end

  def applied_aggregate_function_string
    case aggregate_function
      when 'count'
        "COUNT(#{name_with_table})"
      when 'distinct_count'
        "COUNT(DISTINCT #{name_with_table})"
      when 'min'
        "MIN(#{name_with_table})"
      when 'max'
        "MAX(#{name_with_table})"
      when 'sum'
        "SUM(#{name_with_table})"
      when 'avg'
        "AVG(#{name_with_table})"
      else
        name_with_table
      end
  end


  #----------------------------------------------------------------
  #                           Conditions
  #----------------------------------------------------------------

  def conditions
    @conditions ||= (@column_hash[:conditions] || []).map { |c| DynamicQueries::Condition.new(self, c) }
  end

  #
  # @return [DynamicQueries::Condition] A new condition object
  #   for this query column
  #
  def build_condition(values = {})
    DynamicQueries::Condition.new(self, values)
  end

  def condition_by_identifier(condition_identifier)
    conditions.find { |c| c.identifier.to_s == condition_identifier.to_s } || temporary_condition(condition_identifier)
  end

  def remove_condition(identifier)
    conditions.delete(condition_by_identifier(identifier))
  end

  def update_condition(condition_identifier, new_values = {})
    condition = condition_by_identifier(condition_identifier)

    if condition
      condition.update_attributes(new_values)
      unless condition.valid?
        condition.revert
        return false
      end
    else
      condition = build_condition(new_values.merge({:identifier => condition_identifier}))
      if condition.valid?
        conditions << condition
      else
        @temp_condition = condition
        return false
      end
    end

    true
  end

  #
  # Builds an identifier for this query column that does
  # not change as the result_set_key would and therefore may be used
  # to identify a certain column through multiple requests
  #
  # The identifier begins with a random letter as this a convention
  # for column names and aliases for many RDS
  #
  def identifier
    @identifier ||= ('a'..'z').to_a.choice << SecureRandom.hex
  end

  #
  # @return [Hash]
  #   column details and options.
  #   These are stored in the database instead of the serialized
  #   object to take up less space.
  #
  def to_h
    {
        :model_name         => @column_hash[:model_name],
        :column_name        => @column_hash[:column_name],
        :position           => @position.to_i,
        :custom_name        => @custom_name,
        :show_column        => @show_column,
        :order_by           => @order_by,
        :group_by           => @group_by,
        :order_by_position  => @order_by_position,
        :select_position    => @select_position,
        :identifier         => identifier,
        :aggregate_function => @aggregate_function,
        :conditions         => conditions.map(&:to_h)
    }
  end

  private

  #
  # If a newly created condition is invalid, we have to keep it here
  # during the request to display error messages to the user.
  #
  def temporary_condition(condition_identifier)
    @temp_condition && @temp_condition.identifier == condition_identifier.to_s ? @temp_condition : nil
  end

  #
  # Tries to convert the given value (fixnum or string currently)
  # to a boolean value.
  #
  def bool_value(value)
    case value.class.to_s
      when 'Fixnum' then
        value == 1
      when 'String' then
        value.downcase == 'true' || bool_value(value.to_i)
      when 'TrueClass', 'FalseClass' then
        value
      else
        raise ArgumentError.new("Could not convert '#{value}' to a boolean value")
    end
  end
end