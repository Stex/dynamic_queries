module DynamicQueries::Concerns::Columns
  unloadable if Rails.env.development?

  def columns
    @columns ||= columns_mapping.values.sort_by(&:position)
  end

  def columns_for_clause(clause)
    send("#{clause}_columns")
  end

  #
  # @return [Array<String>] the column names to be part of the query SQL as output
  #   Please note that the columns are already alias'd with their identifiers to
  #   guaratee unique names
  #
  def select_column_names
    select_columns.map(&:select_string)
  end

  #
  # @return [Array<DynamicQueries::QueryColumn>]
  #
  def select_columns
    columns.select(&:show?).sort_by(&:select_position)
  end

  #
  # @return [Array<String>] the column names and directions the query results should be sorted by
  #
  def order_by_column_names
    order_by_columns.map(&:order_by_string)
  end

  #
  # @return [Array<DynamicQueries::QueryColumn>]
  #
  def order_by_columns
    columns.select(&:order_by?).sort_by(&:order_by_position)
  end

  #
  # @return [Array<String>] the column names for the GROUP BY clause
  #
  def group_by_column_names
    group_by_columns.map(&:name_with_table)
  end

  #
  # @return [Array<DynamicQueries::QueryColumn>]
  #
  def group_by_columns
    columns.select(&:group_by?)
  end

  #
  # Adds the given column to the query
  #
  # @return [DynamicQueries::QueryColumn]
  #   The newly created QueryColumn object
  #
  def add_column(model_name, column_name)
    column = column_proxy(model_name, column_name)

    query_column = DynamicQueries::QueryColumn.new self, :model_name  => model_name,
                                                         :column_name => column_name,
                                                         :position    => columns.size

    columns_mapping[query_column.identifier] = query_column
    columns << query_column

    query_column
  end

  #
  # @see #add_column
  #
  def add_column!(*args)
    res = add_column(*args)
    save ? res : nil
  end

  #
  # Removes the given QueryColumn from the query
  #
  # @param [String] column_identifier
  #   The identifier of the query column to be removed
  #
  # @return [DynamicQueries::QueryColumn, NilClass]
  #   The deleted query column object or +nil+ if there was no column for the given identifier
  #
  def remove_column(column_identifier)
    if query_column = columns_mapping.delete(column_identifier)
      columns.delete(query_column)
    end

    query_column
  end

  #
  # @see #add_column
  #
  def remove_column!(*args)
    res = remove_column(*args)
    save ? res : nil
  end

  #
  # Sets an option in the given query column
  #
  # @param [String] column_identifier
  # @param [String] option_name
  # @param [Object] new_value
  #
  # @return [DynamicQueries::QueryColumn] the altered query column object
  #
  def set_column_option(column_identifier, option_name, new_value)
    column = query_column(column_identifier)
    column.set_option(option_name, new_value)
    column
  end

  #
  # @see #set_column_option
  # Difference is that the query is saved afterwards.
  #
  def set_column_option!(*args)
    res = set_column_option(*args)
    save ? res : false
  end

  #
  # @param [DynamicQueries::Column] column
  #
  # @return [Boolean] +true+ if the given column is part of this query.
  #   Note that the query might include it multiple times (e.g. once as count)
  #
  def includes_column?(column)
    columns.any? {|c| c.column == column }
  end

  #
  # @return [Hash] Mapping of identifiers to QueryColumns
  #
  # This method can be used to quickly identify the query column a
  # column in the result set belongs to (or simply quickly access a certain column)
  #
  def columns_mapping
    self.columns_array ||= []

    @columns_mapping ||= Hash[columns_array.map do |column_hash|
      column = DynamicQueries::QueryColumn.new(self, column_hash)
      [column.identifier.to_s, column]
    end]
  end

  #
  # @param [DynamicQueries::Column] column
  #   The column to be searched for in the query columns
  #
  # @return [Array<DynamicQueries::QueryColumn>]
  #   All query columns which use the given column
  #
  def query_columns_for_column(column)
    columns.select {|c| c.column == column }
  end

  #
  # @return [DynamicQueries::QueryColumn, NilClass]
  #   The QueryColumn with the given identifier or +nil+
  #   if none matched it.
  #
  def query_column(identifier)
    columns_mapping[identifier.to_s]
  end

  #
  # Updates the column order for a clause in the query
  #
  # @param [String] order_type
  #   The clause to be updated, e.g. 'order_by' or 'select'
  #
  # @param [Array<String>] order
  #   the query column identifiers in the new order
  #
  def update_column_order(order_type, order)
    return false unless %w[select order_by].include?(order_type.to_s)

    order.each_with_index do |identifier, index|
      query_column(identifier).set_position(order_type, index)
    end

    true
  end

  #
  # @see #update_column_order
  #
  def update_column_order!(*args)
    update_column_order(*args) && save
  end

  #
  # @return [DynamicQueries::Column]
  #
  def column_proxy(model_name, column_name)
    model_proxy(model_name).column_by_name(column_name)
  end

  #----------------------------------------------------------------
  #                           Conditions
  #----------------------------------------------------------------

  #
  # @return [Hash]
  #   The query's conditions for WHERE and HAVING as {DynamicQueries::Conditions::ConditionGroup}
  #
  def conditions
    self.conditions_hash ||= {:where => [], :having => []}
    @conditions ||= Hash[self.conditions_hash.map {|k, v| [k, DynamicQueries::Condition.parse_conditions_string(v || [], self)] }]
  end

  #
  # @return [DynamicQueries::Conditions::ConditionGroup]
  #   The query conditions for the HAVING clause
  #
  def having_conditions
    conditions[:having]
  end

  #
  # @return [DynamicQueries::Conditions::ConditionGroup]
  #   The query conditions for the WHERE clause
  #
  def where_conditions
    conditions[:where]
  end

  def clause_conditions(clause)
    conditions[clause.to_sym]
  end

  #
  # @return [Boolean] +true+ if the given condition values were valid
  #   and the condition was added/updated.
  #
  def update_condition(column_identifier, condition_identifier, new_values = {})
    column = query_column(column_identifier)
    column && column.update_condition(condition_identifier, new_values)
  end


  #
  # @see #update_condition
  #
  def update_condition!(*args)
    update_condition(*args) && save
  end

  #
  # @return [Boolean] +true+ if the given condition was deleted
  #
  def remove_condition(column_identifier, condition_identifier)
    column = query_column(column_identifier)
    column && column.remove_condition(condition_identifier)
  end

  #
  # @see #remove_condition
  #
  def remove_condition!(*args)
    remove_condition(*args) && save
  end

  #
  # Attempts to update the condition order from the given token list
  # The token list is parsed and validated.
  #
  # @param [Hash] conditions_order
  #   Mapping +:having+ and +:where+ to arrays of tokens
  #
  # @return [Boolean] +true+ if the token list was valid
  #
  def update_conditions_order(conditions_order = {})
    @condition_errors   = {}
    result              = true
    new_conditions_hash = {}
    conditions_order  ||= {}

    [:where, :having].each do |clause|
      condition_group = DynamicQueries::Condition.parse_conditions_string(conditions_order[clause.to_s] || [], self)

      if condition_group
        if condition_group.valid?
          new_conditions_hash[clause] = condition_group.serialize
        else
          @condition_errors[clause] = condition_group.errors
          result = false
        end
      else
        @condition_errors[clause] = [I18n.t('dynamic_queries.errors.condition_groups.imbalanced_parenthesis')]
      end
    end

    self.conditions_hash = new_conditions_hash if result
    result
  end

  #
  # @see #update_conditions_order
  #
  def update_conditions_order!(*args)
    update_conditions_order(*args) && save
  end

  def condition_errors(key = nil)
    @condition_errors ||= {:where => [], :having => []}
    key ? (@condition_errors[key.to_sym] || []) : @condition_errors
  end

  #
  # @return [Array<String>]
  #   The variable names required to execute this query correctly
  #
  def required_variable_names
    (where_conditions.required_variable_names + having_conditions.required_variable_names).uniq.compact
  end

  #
  # @return [Boolean] +true+ if the query requires variable values to be executed
  #
  def requires_variables?
    required_variable_names.any?
  end
  
  #
  # @return [Boolean] +true+ if the given variable assignment is sufficient to execute the query
  #
  def sufficient_variables?(given_variables)
    return false if requires_variables? && !given_variables
    where_conditions.sufficient_variables?(given_variables) && having_conditions.sufficient_variables?(given_variables)
  end

  private

end