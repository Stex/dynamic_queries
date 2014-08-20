class DynamicQueries::ResultSet
  unloadable if Rails.env.development?

  #Timeout for query execution in #show
  EXECUTION_TIMEOUT = 15000

  include DynamicQueries::DatabaseHelpers

  delegate :each, :first, :last, :count, :[], :to => :processed_results

  def initialize(query, options = {})
    @query   = query
    @options = options
    build_custom_order!
  end

  def processed_results
    @processed_results ||= execute_query(@options).each_with_index.map do |result_hash, index|
      Hash[
        [[:__row_number__, index + offset + 1]] + result_hash.map do |k, v|
          column = @query.query_column(k)
          [column, process_value(column, v)]
        end
      ]
    end
  end

  #
  # @return [Fixnum] the total number of records returned by the query
  #   Limit and Offset are ignored here.
  #
  def total_count
    unless @total_count
      with_sql_timeout do
        res = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as row_count FROM (#{@query.to_sql(:variables => variables)}) AS subquery")
        @total_count = res.first['row_count'].to_i
      end
    end
    @total_count
  end

  def page
    @options[:page].to_i
  end

  def per_page
    @options[:per_page].to_i
  end

  def variables
    @options[:variables] || {}
  end

  #
  # @return [Array<Fixnum>] The page numbers to be displayed in the pagination
  #
  def pagination_pages
    res = []
    if page == 1
      res << pagination_string('&laquo;')
    else
      res << pagination_page(page - 1, '&laquo;')
    end

    res << pagination_page(1)
    res << pagination_string('...') if page - 4 > 1
    res += (page - 5 .. page + 5).select {|i| i > 1 && i < page_count}.map {|n| pagination_page(n)}
    res << pagination_string('...') if page + 4 < page_count
    res << pagination_page(page_count)

    if page == page_count
      res << pagination_string('&raquo;')
    else
      res << pagination_page(page + 1, '&raquo;')
    end

    res.uniq
  end

  #
  # @return [Fixnum] the amount of pages this query could fill
  #
  def page_count
    count = total_count / per_page
    total_count % per_page == 0 ? count : count + 1
  end

  def to_csv
    FasterCSV.generate(:col_sep => ',', :headers => :first_row) do |csv|
      csv << @query.select_columns.map(&:output_name)
      to_csv_rows.each {|row| csv << row}
    end
  end

  #
  # @return [Boolean] +true+ if the query execution was stopped
  #   as it took more than EXECUTION_TIMEOUT ms
  #
  def execution_timeout?
    processed_results
    !!@execution_timeout
  end

  private

  #
  # Temporarily changes the order_by value of the query columns
  # Do NOT save the query after this was done (shouldn't happen as it will only happen in #show)
  #
  def build_custom_order!
    if custom_order = @options.delete(:custom_order)
      order_by_columns = []
      @query.columns.each do |column|
        if direction = custom_order[column.identifier]
          column.order_by = direction
        else
          column.order_by = nil
        end
      end
    end
  end

  #
  # @return [Fixnum] the offset the current query execution will start with
  #
  def offset
    return @options[:offset].to_i if @options[:offset]
    return (@options[:page].to_i - 1) * @options[:per_page] if @options[:page] && @options[:per_page]
    0
  end

  #
  # @return [Array<Array<String, Numeric>>]
  #   Rows and columns to be used with FasterCSV
  #
  def to_csv_rows
    res = []
    each do |result|
      row = []
      @query.select_columns.each do |column|
        row << result[column].to_s
      end
      res << row
    end
    res
  end

  def pagination_page(number, caption = nil)
    caption ||= number.to_s
    caption = caption.html_safe if caption.respond_to?(:html_safe)
    {:class => number == page ? 'active' : '', :caption => caption, :number => number}
  end

  def pagination_string(str)
    str = str.html_safe if str.respond_to?(:html_safe)
    {:class => 'disabled', :caption => str}
  end

  def process_value(column, value)
    case column.type.to_s
      when 'boolean'
        !!value
      else
        value
    end
  end

  def execute_query(options)
    begin
      with_sql_timeout(EXECUTION_TIMEOUT) do
        @query.main_model.model_class.connection.select_all(@query.to_sql(options))
      end
    rescue ActiveRecord::StatementInvalid => e
      if sql_timeout?(e)
        @execution_timeout = true
      end
      {}
    end
  end
end