require 'securerandom'

#
# This class represents a single condition set up for a query
#
class DynamicQueries::Condition
  unloadable if Rails.env.development?

  COMPARATORS       = %w[= <> < <= > >= LIKE]
  CONDITION_TYPES   = %w[null_test value column variable]
  CONDITION_CLAUSES = [:where, :having]

  #
  # Parses a SQL conditions string
  #
  # @return [DynamicQueries::Conditions::ConditionsGroup, NilClass]
  #   +nil+ if the given conditions string as unmatched parenthesis
  #
  def self.parse_conditions_string(str_or_tokens, query)
    if str_or_tokens.is_a?(String)
      #Sanitize the string to have every token separated by space(s)
      new_str = str_or_tokens.gsub(/\(([^ \(]?)/, '( \1').gsub(/([^ \)]?)\)/, '\1 )')
      tokens  = new_str.split(' ')
    else
      tokens = str_or_tokens
    end

    level  = 0
    heap   = {0 => []}

    tokens.each do |token|
      case token.downcase
        when 'and', 'or'
          heap[level] << DynamicQueries::Conditions::Connector.new(token, query)
        when '('
          level       += 1
          heap[level] = []
        when ')'
          level -= 1
          if heap[level + 1].size > 1
            heap[level] << DynamicQueries::Conditions::ConditionGroup.new(heap[level + 1], query)
          elsif heap[level + 1].size == 1
            heap[level] += heap[level + 1]
          end
        else
          heap[level] << DynamicQueries::Conditions::Identifier.new(token, query)
      end
    end

    level.zero? ? DynamicQueries::Conditions::ConditionGroup.new(heap[0], query) : nil
  end

  def initialize(query_column, options_hash = {})
    @options_hash = options_hash
    @query_column = query_column

    update_attributes(options_hash)
    @condition_type ||= CONDITION_TYPES.first
  end

  def to_s
    res =  "#{query_column.output_name} "
    res << "#{comparator} " unless type?(:null_test)
    res << right_side_string
  end

  def right_side_string
    case condition_type
      when 'null_test' then null_test_string
      when 'value'     then "\"#{compare_value}\""
      when 'variable'  then "V[#{compare_variable_name}]"
      when 'column'    then compare_column.output_name
      else 'unknown'
    end
  end

  def identifier
    @identifier ||= SecureRandom.hex
  end

  alias_method :id, :identifier

  #
  # Reverts the condition to the last database state
  #
  def revert
    update_attributes(@options_hash)
  end

  #
  # @return [Boolean] +true+ if the given attributes were valid
  #
  def update_attributes(new_attributes = {})
    [:condition_type, :identifier,
     :comparator, :null_test_value, :compare_column_identifier,
     :compare_value, :compare_variable_name].each do |k|
      next unless new_attributes.has_key?(k)
      instance_variable_set("@#{k}", new_attributes[k])
    end
  end

  def model_name
    @query_column.model.to_s
  end

  def column_name
    @query_column.name
  end

  def type?(t)
    condition_type == t.to_s
  end

  #
  # @return [DynamicQueries::QueryColumn]
  #   The query column this condition was done for
  #
  def query_column
    @query_column
  end

  def condition_type
    @condition_type.to_s
  end

  def condition_type=(new_type)
    @condition_type = new_type
  end

  #
  # @return [Boolean] +true+ if this condition may be used
  #    in the WHERE clause of the sql query
  #
  def where_condition?
    !having_condition?
  end

  #
  # @return [Boolean] +true+ if this condition may be used
  #   in the HAVING clause of the query.
  #   This is the case for functions like COUNT or sum (aggregate functions)
  #
  def having_condition?
    query_column.aggregate_function?
  end

  #----------------------------------------------------------------
  #                          View Helpers
  #----------------------------------------------------------------

  #
  # @return [Array<Array<String, String>>]
  #   A list of captions and column identifiers to be used with a select or select tag
  #   in the conditions form.
  #
  def column_options
    (@query_column.query.columns - [query_column]).map { |c| [c.output_name, c.identifier] }
  end

  #
  # @return [Array<String>] All possible comparators
  #
  def comparator_options
    COMPARATORS
  end

  #----------------------------------------------------------------
  #                      IS NULL / IS NOT NULL
  #----------------------------------------------------------------

  def null_test_value
    @null_test_value
  end

  def null_test_value=(new_value)
    @null_test_value = new_value
  end

  def null_test_string
    null_test_value == 'null' ? 'IS NULL' : 'IS NOT NULL'
  end

  #----------------------------------------------------------------
  #                     Compare to a given value
  #----------------------------------------------------------------

  def compare_value
    @compare_value
  end

  def compare_value=(new_value)
    @compare_value = new_value
  end

  def comparator
    @comparator ||= COMPARATORS.first
  end

  def comparator=(new_value)
    @comparator = new_value if COMPARATORS.include?(new_value)
  end

  #----------------------------------------------------------------
  #                     Compare to another column
  #----------------------------------------------------------------

  def compare_column_identifier
    @compare_column_identifier
  end

  def compare_column_identifier=(column_identifier)
    @compare_column_identifier = column_identifier
  end

  #
  # @return [DynamicQueries::QueryColumn]
  #   The query column this one should be compared to
  #
  def compare_column
    query_column.query.query_column(@compare_column_identifier)
  end

  #----------------------------------------------------------------
  #                        Compare to a variable
  #----------------------------------------------------------------

  def compare_variable_name
    @compare_variable_name
  end

  def compare_variable_name=(new_variable_name)
    @compare_variable_name = new_variable_name
  end

  #----------------------------------------------------------------
  #                     Compare to a FIXED variable            TODO
  #----------------------------------------------------------------

  #----------------------------------------------------------------
  #                           Validations
  #----------------------------------------------------------------

  #
  # @return [Boolean] +true+ if the condition is valid in its current state
  #
  # Like in ActiveRecord, a condition is valid if it has no error messages
  # after validations were done.
  #
  def valid?
    if respond_to?("validate_type_#{condition_type}")
      send("validate_type_#{condition_type}")
      errors.empty?
    else
      false
    end
  end

  #
  # Ensures that the null check value is either the one for NULL or NOT NULL
  #
  def validate_type_null_test
    unless %w[null not_null].include?(null_test_value)
      add_error(:null_test_value, :invalid_value)
    end
  end

  #
  # Only validates the comparator as the value may actually be empty,
  # e.g. when testing for an emtpy string as value
  #
  def validate_type_value
    validate_comparator
  end

  #
  # Validates the comparator and ensures that a variable name is given
  #
  def validate_type_variable
    validate_comparator

    if compare_variable_name.blank?
      add_error(:compare_variable_name, :blank)
    end
  end

  #
  # Validates the comparator and makes sure that the given column
  # identifier actually exists
  #
  def validate_type_column
    validate_comparator

    unless compare_column
      add_error(:compare_column_identifier, :unknown_identifier)
    end
  end

  #
  # Validates that the set comparator is one from the comparator list
  #
  def validate_comparator
    unless COMPARATORS.include?(comparator)
      add_error(:comparator, :invalid_value)
    end
  end

  #
  # @return [Hash]
  #   Serialized options representing this condition.
  #   It is used to save it in the columns array in the database
  #
  def to_h
    {
        :condition_type            => @condition_type,
        :identifier                => identifier,

        :comparator                => comparator,
        :null_test_value           => null_test_value,
        :compare_column_identifier => compare_column_identifier,
        :compare_value             => compare_value,
        :compare_variable_name     => compare_variable_name
    }
  end

  #----------------------------------------------------------------
  #                          Error Handling
  #----------------------------------------------------------------

  def errors_on(on)
    errors[on.to_sym]
  end

  def errors_on?(on)
    !!errors[on.to_sym].try(:any?)
  end

  private

  def errors
    @errors ||= {}
  end

  def add_error(on, error_key, options = {})
    errors[on.to_sym] ||= []
    options[:scope]   = "dynamic_queries.errors.conditions.#{on}"
    errors[on.to_sym] << I18n.t(error_key, options)
  end
end