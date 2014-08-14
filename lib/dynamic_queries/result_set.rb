class DynamicQueries::ResultSet
  unloadable if Rails.env.development?

  delegate :each, :first, :last, :count, :[], :to => :processed_results

  def initialize(query, options = {})
    @query   = query
    @options = options
    @results = execute_query(options)
  end

  def processed_results
    @processed_results ||= @results.map do |result_hash|
      Hash[
        result_hash.map do |k, v|
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
      res = ActiveRecord::Base.connection.execute("SELECT COUNT(*) as row_count FROM (#{@query.to_sql(:variables => variables)}) AS subquery")
      @total_count = res.first['row_count'].to_i
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

  private

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
    @query.main_model.model_class.connection.select_all(@query.to_sql(options))
  end

end