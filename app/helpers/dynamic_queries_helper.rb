module DynamicQueriesHelper
  unloadable if Rails.env.development?

  ACTION_ICONS = {
      :add    => 'plus',
      :remove => 'minus',
      :edit   => 'pencil'
  }

  #
  # Generates HAML options for the model panels during query creation
  #
  def model_panel_options(model)
    options = {
        :data  => {
            'model-name' => model.to_s
        },
        :id    => model.dom_id,
        :style => 'position: absolute'
    }

    options[:class] = @query.main_model?(model) ? 'panel-success' : 'panel-default'

    if positions = @query.model_positions[model.to_s]
      options[:data]['position-left'] = positions[:left]
      options[:data]['position-top']  = positions[:top]
    end

    options
  end

  #
  # @return [String] the query's current associations as a JSON string
  #   to be used as connections by the javascript library during the associations action
  #
  def associations_json(&label_function)
    json = @query.associations.values.flatten.map do |association|
      if block_given?
        label = label_function.call(@query, association)
      else
        label = link_to_remote remove_icon, :url => dq_url(:remove_association, @query, :model_name => association.model.to_s, :association => association.name)
      end

      {
          :source           => "##{association.model.dom_id}",
          :target           => "##{association.end_point.dom_id}",
          :label            => label,
          :association      => "##{association.dom_id}",
          :association_name => association.name
      }

    end.to_json

    json.respond_to?(:html_safe) ? json.html_safe : json
  end

  def remove_icon
    content_tag(:span, nil, :class => 'glyphicon glyphicon-remove text-danger')
  end

  #
  # Generates a remote link to add a new association to the query
  #
  def add_association_link(association)
    if ''.respond_to?(:html_safe)
      caption = ''.html_safe << association.name.to_s.html_safe << ' '.html_safe << badge(association.macro_string)
    else
      caption = association.name.to_s + ' ' + badge(association.macro_string)
    end

    link_to_remote caption, :url => dq_url(:add_association, @query, :model_name => association.model.name, :association => association.name),
                   :html         => association_row_options(association)
  end

  #
  # Generates HAML options for association rows inside the model panels
  #
  def association_row_options(association)
    options         = {}
    options[:id]    = association.dom_id
    options[:class] = 'list-group-item'
    options[:class] += ' list-group-item-info' if @query.has_association?(association)
    options
  end

  #
  # Helper method to generate a bootstrap badge element
  #
  def badge(caption, options = {})
    classes = (options[:class] || '').split(' ')
    classes << 'badge'
    options[:class] = classes.join(' ')

    if ''.respond_to?(:html_safe)
      ' '.html_safe << content_tag(:span, h(caption), options).html_safe
    else
      content_tag(:span, h(caption), options)
    end
  end

  def columns_associations_json
    associations_json do |query, association|
      association.name
    end
  end

  def current_step?(step)
    @step == step.to_s || params[:action] == step.to_s || step.to_s == 'edit' && params[:action] == 'new'
  end

  #
  # Generates a HAML options hash for column rows
  # in the columns step of query creation
  #
  def column_row_options(column)
    options = {}
    options[:class] = 'info' if @query.includes_column?(column)
    options
  end

  #
  # Shortens the given string to +count+ chars
  # and puts ellipsis in the middle.
  #
  def ellipsis_snippet(text, count = 20)
    return text.to_s if text.to_s.length <= count + 1

    first  = count / 2
    second = count - first
    text.chars.select.each_with_index {|_, i| i <= first}.join + '...' + text.chars.select.each_with_index {|_, i| i >= (text.length - second)}.join
  end

  #
  # Generates a bootstrap glyphicon tag as checkbox replacement
  #
  def checkbox_icon(checked = false)
    if checked
      content_tag(:span, nil, :class => 'glyphicon glyphicon-check')
    else
      content_tag(:span, nil, :class => 'glyphicon glyphicon-unchecked')
    end
  end

  def action_icon(action_name, options = {})
    glyphicon(ACTION_ICONS[action_name.to_sym], options)
  end

  #
  # Generates the data attributes for input fields
  # to set column options through AJAX calls
  #
  # @param [DynamicQueries::QueryColumn] column
  #
  # @param [Hash] other_options
  #   If the input field does only accept one options hash,
  #   these other options may be added to this method and will be used
  #   in the returned hash
  #
  # @return [Hash] Data Attributes and other options
  #
  def column_options_data(column, option, other_options = {})
    options = other_options.clone

    options[:id] = column.dom_id(option.to_s)

    {
        :column_option     => true,
        :url               => dq_url(:set_column_option, @query),
        :option_name       => option.to_s,
        :column_identifier => column.identifier
    }.each {|k,v| options["data-#{k.to_s.gsub('_', '-')}"] = v}

    options
  end

  def sort_directions(column)
    options_for_select([['', ''], [dqt('sort_directions.asc'), 'ASC'], [dqt('sort_directions.desc'), 'DESC']], column.order_by)
  end

  def aggregate_function_options(column)
    options_for_select(column.available_aggregate_function_options, column.aggregate_function)
  end

  #
  # Generate a bootstrap glyphicon tag displaying a left-right move icon
  #
  def change_order_icon
    glyphicon('resize-horizontal')
  end

  #
  # Generates a link_to_function to toggle column sorting options
  #
  def change_order_link(caption, type)
    link_to_function "#{caption} #{change_order_icon}".try_html_safe, "dynamicQueries.actions.columnOptions.toggleColumnSorting('#{type}')",
                     :title => dqt('actions.change_column_order')
  end

  def sort_icon(direction = 'asc')
    klass = direction.downcase == 'asc' ? 'sort-by-attributes' : 'sort-by-attributes-alt'
    glyphicon(klass, :title => direction)
  end

  def glyphicon(klass, options = {})
    options[:class] = "glyphicon glyphicon-#{klass}"
    content_tag(:span, nil, options)
  end

  def update_conditions_modal(content_or_hash)
    content = content_or_hash.is_a?(Hash) ? render(content_or_hash) : content_or_hash
    "dynamicQueries.actions.columnOptions.conditionsModal('update', '#{escape_javascript(content)}');".try_html_safe
  end

  def show_conditions_modal
    "dynamicQueries.actions.columnOptions.conditionsModal('show');".try_html_safe
  end

  def hide_conditions_modal
    "dynamicQueries.actions.columnOptions.conditionsModal('hide');".try_html_safe
  end

  #
  # @return [String] The value given for the given variable name
  #
  def given_variable_value(variable_name)
    params[:variables] && params[:variables][variable_name]
  end

  #----------------------------------------------------------------
  #                        JS Helpers
  #----------------------------------------------------------------

  def add_model_panel(model)
    js_prepend_element_to '#dynamic_queries .model-canvas', :partial => 'dynamic_queries/associations/model_panel', :object => model
  end

  def remove_model_panel(model)
    js_remove_element "##{model.dom_id}"
  end

  def init_draggables
    'dynamicQueries.actions.associations.initModelDraggables();'
  end

  def redraw_connections
    res = "dynamicQueries.actions.associations.redrawConnections(#{associations_json});"
    res.respond_to?(:html_safe) ? res.html_safe : res
  end

  def update_model_panel(model, step = 'associations')
    js_update_element "##{model.dom_id}", :partial => "dynamic_queries/#{step}/model_associations", :locals => {:model => model}
  end

  def resize_canvas
    'dynamicQueries.actions.associations.resizeCanvas();'
  end
end