class DynamicQueries::Conditions::Identifier
  unloadable if Rails.env.development?

  def initialize(name, query)
    @column_identifier, @condition_identifier = name.split('.')
    @query    = query
  end

  def query_column
    @query.query_column(@column_identifier)
  end

  def condition
    query_column.try(:condition_by_identifier, @condition_identifier)
  end

  def to_sql(_)
    sql = [query_column.condition_clause_identifier]

    if condition.type?(:null_test)
      sql <<  condition.null_test_string
    else
      sql << condition.comparator

      if condition.type?(:column)
        sql << condition.compare_column.name_with_table
      else
        sql << '?'
      end
    end

    sql.join(' ')
  end

  def condition_values(variables)
    if condition.type?(:value)
      [condition.compare_value]
    elsif condition.type?(:variable)
      [variables[condition.compare_variable_name]]
    else
      []
    end
  end

  def simple_string
    'I'
  end

  def serialize(_)
    [[@column_identifier, @condition_identifier].join('.')]
  end

  def to_array(_)
    [condition]
  end

  #
  # @return [Array<String>]
  #   If this condition is a variable condition, this function will
  #   return the variable name, otherwise an empty array
  #
  def required_variable_names
    condition.type?(:variable) ? [condition.compare_variable_name.to_s] : []
  end

  #
  # @return [Boolean] +true+ if the given variables are sufficient for this condition
  #
  def sufficient_variables?(variables)
    return true unless condition.type?(:variable)
    return false unless variables[condition.compare_variable_name]

    #Numeric columns may not be compared with empty strings
    if query_column.column.klass < Numeric
      return false if variables[condition.compare_variable_name].blank?
    end

    true
  end

  #
  # Checks if this condition identifier is valid.
  # This is the case if
  #
  #  1. the query column is still part of the query
  #  2. the condition identifier matches a condition in this query column
  #
  def valid?(_)
    query_column && condition
  end
end