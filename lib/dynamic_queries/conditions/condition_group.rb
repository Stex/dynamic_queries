class DynamicQueries::Conditions::ConditionGroup
  unloadable if Rails.env.development?

  def initialize(elements, query)
    @elements = elements
    @query    = query
  end

  def to_sql(outermost = true)
    sql = @elements.map {|e| e.to_sql(false)}.join(' ')
    outermost ? sql : "(#{sql})"
  end

  def condition_values(variables = {})
    @elements.inject([]) do |values, element|
      values + element.condition_values(variables)
    end
  end

  #
  # Checks if this condition group is valid. This means:
  #
  #   - A connector may only be between 2 identifiers or valid condition groups
  #   - No 2 identifiers may be placed after another
  #   - A condition group may not start or end with a connector
  #
  # It also checks if all elements are valid as well
  #
  def valid?(outermost = true)
    if outermost
      add_error(:unconnected_identifiers)   if simple_string =~ /II/
      add_error(:connector_after_connector) if simple_string =~ /CC/
      add_error(:starting_with_connector)   if simple_string =~ /^C/
      add_error(:ending_with_connector)     if simple_string =~ /C$/

      errors.empty? && @elements.all? { |e| e.valid?(false) }
    else
      @elements.all? {|e| e.valid?(false)}
    end
  end

  def errors
    (@errors || []).uniq.compact
  end

  def to_array(outermost = true)
    return [] if empty?
    array = @elements.inject([]) {|array, element| array + element.to_array(false) }
    outermost ? array : ['('] + array + [')']
  end

  def empty?
    @elements.empty?
  end

  def any?
    @elements.any?
  end

  #
  # @return [Array<String>] An array to be serialized in the query object
  #
  def serialize(outermost = true)
    return [] if empty?
    array = @elements.inject([]) {|array, element| array + element.serialize(false) }
    outermost ? array : ['('] + array + [')']
  end

  #
  # @return [Array<String>] All variable names used in conditions in this group
  #
  def required_variable_names
    @elements.inject([]) do |array, element|
      array + element.required_variable_names
    end.uniq.compact
  end

  #
  # @return [Boolean] +true+ if the given variable assignment is sufficient
  #   for all elements in this condition group
  #
  def sufficient_variables?(variables)
    @elements.all? {|e| e.sufficient_variables?(variables)}
  end

  private

  def simple_string
    @elements.map(&:simple_string).join
  end

  def add_error(error_key)
    @errors ||= []
    @errors << I18n.t(error_key, :scope => 'dynamic_queries.errors.condition_groups')
  end
end