class DynamicQueries::Conditions::Connector
  unloadable if Rails.env.development?

  def initialize(connector, query)
    @connector = connector
    @query     = query
  end

  def to_sql(_)
    @connector.to_s.upcase
  end

  def condition_values(_)
    []
  end

  def simple_string
    'C'
  end

  def serialize(_)
    [@connector]
  end

  def to_array(_)
    [@connector.upcase]
  end

  def valid?(_)
    %w[and or].include?(@connector.downcase)
  end

  def required_variable_names
    []
  end

  def sufficient_variables?(_)
    true
  end
end