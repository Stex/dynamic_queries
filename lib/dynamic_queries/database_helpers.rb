module DynamicQueries::DatabaseHelpers
  unloadable if Rails.env.development?

  private

  #
  # Temporarily sets the database statement timeout for the given block
  # @todo: Currently, this only works for postgresql, should be extended for other RDS
  #
  def with_sql_timeout(timeout = 2000, &proc)
    begin
      ActiveRecord::Base.connection.execute("SET statement_timeout TO #{timeout};")
      yield
    ensure
      ActiveRecord::Base.connection.execute('RESET statement_timeout;')
    end
  end

  #
  # Tests if the given SQL string is valid SQL
  #
  # Please note that database timeouts are not counted
  # as sql errors as the query itself worked, it just took too
  # long to be executed
  #
  def sql_error?(sql)
    error, reason = thrown_sql_error(sql)
    !!error && reason != :timeout
  end

  #
  # Tries to execute the query and captures possible SQL errors occuring
  #
  # @return [String, NilClass]
  #   The error message if an error occurred, +nil+ otherwise
  #
  def thrown_sql_error(sql)
    @tested_queries ||= {}
    return @tested_queries[sql] if @tested_queries.has_key?(sql)

    error  = nil
    reason = nil

    begin
      with_sql_timeout(DynamicQueries::Query::TIMEOUT_MS) do
        ActiveRecord::Base.connection.execute(sql)
      end
    rescue ActiveRecord::StatementInvalid => e
      if sql_timeout?(e)
        error  = I18n.t('dynamic_queries.errors.sql_timeout', :timeout => DynamicQueries::Query::TIMEOUT_MS)
        reason = :timeout
      else
        error  = e.message.lines.first.strip
        reason = :invalid_sql
      end
    rescue Exception => e
      logger.error e.message
      logger.error e.backtrace.join("\n")
      error  = e.message
      reason = :other
    end

    @tested_queries[sql] = [error, reason]
  end

  #
  # @param [Exception] error
  #   The error thrown by the connection adapter
  #
  # @return [Boolean] +true+ if the given error message was caused by a timeout
  #
  def sql_timeout?(error)
    case ActiveRecord::Base.configurations[Rails.env]['adapter']
      when 'postgresql'
        !!(error.message =~ /^PG::QueryCanceled/)
      else
        raise Exception.new("Unsupported Database Adapter: #{ActiveRecord::Base.configurations[Rails.env]['adapter']}")
    end
  end
end