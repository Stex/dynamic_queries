window.dynamicQueries =
  csrf: {}

#
# Loads the protect from forgery token from Rails' meta tag for easer usage
#
  loadCSRF: () ->
    dynamicQueries.csrf.param = jQuery('meta[name=csrf-param]').attr("content")
    dynamicQueries.csrf.token = jQuery('meta[name=csrf-token]').attr("content")

#
# Builds a jQuery data object with the current CSRF token
#
  CSRFdata: (data) ->
    data = {} unless data?
    data[dynamicQueries.csrf.param] = dynamicQueries.csrf.token
    data

  actions:

  #----------------------------------------------------------------
  #                        SHOW action
  #----------------------------------------------------------------

    show:

    #
    # Initializes the custom order sortable on #show
    # It works by setting a hidden position field in each of the
    # sortable elements
    #
      init: () ->
        $("ul.sorting-list").sortable
          axis: 'x'
          items: "li:not(.no-sorting)"
          update: (event, ui) ->
            pos = 0
            $(event.target).find('li:not(.no-sorting)').each () ->
              $(@).find("input[type=hidden]").val(pos)
              pos++

  #----------------------------------------------------------------
  #                    Model Selection Step
  #----------------------------------------------------------------

    new:
      init: () ->
        $('input[type=checkbox]').click () ->
          dynamicQueries.actions.new.handleCheckbox(@)
        $('input[type=radio]').click () ->
          dynamicQueries.actions.new.handleRadio(@)
        $('input[type=radio]:checked').each () ->
          dynamicQueries.actions.new.handleRadio(@)

      handleCheckbox: (elem) ->
        if $(elem).prop('checked')
          $(elem).parents('tr').addClass('info')
        else
          $(elem).parents('tr').removeClass('info')

    #When a new main model is chosen, make sure that
    # 1. its row gets a distinctive colour
    # 2. it is also part of the models (checkbox checked)
    # 3. it can't be removed from the models (checkbox deactivated)
      handleRadio: (elem) ->
        row      = $(elem).parents('tr')
        table    = $(elem).parents('table')
        checkbox = row.find('input[type=checkbox]')

        table.find('tr').removeClass('success')
        table.find('input[type=checkbox]').prop('readonly', false)

        table.find('input[type=checkbox]').each () ->
          dynamicQueries.actions.new.handleCheckbox(@)

        row.addClass('success').removeClass('info')
        checkbox.prop('readonly', true)
        checkbox.prop('checked', true)

  #----------------------------------------------------------------
  #                        Associations Step
  #----------------------------------------------------------------

    associations:
      lowermostBottom: 0
      updatePositionsUrl: null
      connections: []

      init: (url, connections) ->
        $(document).ready () ->
          dynamicQueries.actions.associations.updatePositionsUrl = url
          dynamicQueries.actions.associations.connections = connections

          dynamicQueries.actions.associations.initModelDraggables()
          dynamicQueries.actions.associations.setBoxPositions()
          dynamicQueries.actions.associations.resizeCanvas()
          dynamicQueries.actions.associations.drawAllConnections()

    #
    # Sets the model box positions within the canvas.
    # The top and left positions are taken from 'data-position-X' attributes
    # in the panel
    #
      setBoxPositions: () ->
        $('#dynamic_queries .model').each () ->
          box = $(@)
          if box.data('positionTop')
            box.css('top', box.data('positionTop'))
          if box.data('positionLeft')
            box.css('left', box.data('positionLeft'))

    #
    # Initializes the draggable functionality of the model boxes
    # using jQuery UI in the background.
    #
    # Once a box is released, an AJAX call is made to inform the server
    # about the new box positions.
    #
      initModelDraggables: () ->
        jsPlumb.draggable $('#dynamic_queries .model'),
          handle:      '.panel-heading'
          scroll:      true

          drag: (event, ui) ->
            container = $('#dynamic_queries .model-canvas')
            containerRightBorder = container.position().left + container.width()

            #Custom containment function which allows free drag over the canvas' bottom
            if ui.position.left < container.position().left
              ui.position.left = container.position().left
            if ui.position.top < container.position().top
              ui.position.top = container.position().top
            if ui.position.left > (containerRightBorder - ui.helper.outerWidth())
              ui.position.left = containerRightBorder - ui.helper.outerWidth()

        #on drag stop, resize the canvas to fit all model boxes
          stop: (event, ui) ->
            dynamicQueries.actions.associations.resizeCanvas()

            #Send the current model box positions to the server
            positions = {}
            $('#dynamic_queries .model').each () ->
              positions[$(@).data('modelName')] = [$(@).position().top, $(@).position().left]

            $.post(dynamicQueries.actions.associations.updatePositionsUrl,
              dynamicQueries.CSRFdata({'positions': positions}), null, 'script')

    #
    # Adjusts the canvas height to fit all model boxes.
    # This is necessary in 2 cases:
    #   1. The page was just loaded and the boxes moved to their saved positions
    #   2. A model box was dragged to a new position which is below the old canvas bottom
    #
      resizeCanvas: () ->
        dynamicQueries.actions.associations.updateLowermostBottom()
        $('#dynamic_queries .model-canvas').css('height', dynamicQueries.actions.associations.lowermostBottom)

    #
    # Determines the bottom position of the lowermost model box
    # This is mainly used to resize the canvas to contain all boxes.
    #
      updateLowermostBottom: () ->
        canvasTop = $('#dynamic_queries .model-canvas').position().top
        newBottom = 0
        $('#dynamic_queries .model').each () ->
          relativeBottom = $(@).position().top + $(@).height() - canvasTop
          newBottom = Math.max(newBottom, relativeBottom)
        dynamicQueries.actions.associations.lowermostBottom = newBottom

    #
    # Draws a connection from +source+ to +target+
    #
      drawConnection: (connection) ->
        source = jsPlumb.addEndpoint $(connection.source),
          isSource: true
          anchor: dynamicQueries.actions.associations.dynamicAnchors(connection)
          endpoint: ["Dot", {
            radius: 5
          }]

        dest = jsPlumb.addEndpoint $(connection.target),
          isTarget: true
          anchor: "Continuous"
          endpoint: "Blank"

        jsPlumb.connect
          'source': source
          'target': dest
          connector:     "StateMachine"
          paintStyle:
            lineWidth:3
            strokeStyle: "#D9EDF7"
          hoverPaintStyle:
            strokeStyle: "#C4E3F3"
          overlays: [
            ["PlainArrow", {location:1, width:20, length:12}],
            ["Label", {'label': connection.label, cssClass: "connection-label"}]
          ]

    #
    # Removes all connections from the canvas
    #
      clearConnections: () ->
        jsPlumb.reset()

    #
    # Clears the current connections and redraws them
    # If new connections are given as argument, they will be used instead of the old ones
    #
      redrawConnections: (newConnections) ->
        dynamicQueries.actions.associations.connections = newConnections if newConnections?
        dynamicQueries.actions.associations.clearConnections()
        dynamicQueries.actions.associations.drawAllConnections()

    #
    # Draws all connections saved in +connections+
    # Expects connections to be an object containing source, target and label
    #
      drawAllConnections: () ->
        $.each dynamicQueries.actions.associations.connections, () ->
          dynamicQueries.actions.associations.drawConnection @

      dynamicAnchors: (connection) ->
        verticalCenter = ($(connection.association).position().top + ($(connection.association).height() / 2)) / $(connection.source).height()

        [[0, verticalCenter, -1, 0]
         [1, verticalCenter, 1, 0]]

    columns:
      init: (url, connections) ->
        $(document).ready () ->
          dynamicQueries.actions.associations.updatePositionsUrl = url
          dynamicQueries.actions.associations.connections        = connections

          dynamicQueries.actions.associations.initModelDraggables()
          dynamicQueries.actions.associations.setBoxPositions()
          dynamicQueries.actions.associations.resizeCanvas()
          dynamicQueries.actions.columns.drawAllConnections()


    #
    # Draws a connection from +source+ to +target+
    #
      drawConnection: (connection) ->
        source = jsPlumb.addEndpoint $(connection.source),
          isSource: true
          anchor: "Continuous"
          endpoint: ["Dot", {
            radius: 5
          }]

        dest = jsPlumb.addEndpoint $(connection.target),
          isTarget: true
          anchor: "Continuous"
          endpoint: "Blank"

        jsPlumb.connect
          'source': source
          'target': dest
          connector:     "StateMachine"
          paintStyle:
            lineWidth:3
            strokeStyle: "#D9EDF7"
          hoverPaintStyle:
            strokeStyle: "#C4E3F3"
          overlays: [
            ["PlainArrow", {location:1, width:20, length:12}],
            ["Label", {'label': connection.label, cssClass: "connection-label"}]
          ]

    #
    # Clears the current connections and redraws them
    # If new connections are given as argument, they will be used instead of the old ones
    #
      redrawConnections: (newConnections) ->
        dynamicQueries.actions.associations.connections = newConnections if newConnections?
        dynamicQueries.actions.associations.clearConnections()
        dynamicQueries.actions.columns.drawAllConnections()

    #
    # Draws all connections saved in +connections+
    # Expects connections to be an object containing source, target and label
    #
      drawAllConnections: () ->
        $.each dynamicQueries.actions.associations.connections, () ->
          dynamicQueries.actions.columns.drawConnection @

  #----------------------------------------------------------------
  #                        Query Options Step
  #----------------------------------------------------------------

    columnOptions:

    #
    # Set up change handlers for all column option inputs
    # to make them submit their changed values via an AJAX call
    #
      init: () ->
        dynamicQueries.actions.columnOptions.initColumnSortables()
        dynamicQueries.actions.columnOptions.initConditionCreation()

        #According to the jQuery documentation, .change waits for text fields
        #and text areas to lose focus, so we can use one callback for all types of inputs
        $(document).on 'change', '[data-column-option]', () ->
          elem = $(@)

          value = elem.val()
          if elem.attr('type') == 'checkbox'
            value = if elem.prop('checked') then '1' else '0'

          params = dynamicQueries.CSRFdata
            'value':       value
            'column_identifier': elem.data('columnIdentifier')
            'option_name': elem.data('optionName')

          $.post elem.data('url'), params, null, 'script'


        #Initialize the condition type radio buttons
        $(document).on 'change', 'input[type=radio][data-init=show-condition-type]', () ->
          elem = $(@)
          table = elem.parents('.modal-body').find('table')
          table.find('td.condition-type').hide()
          table.find("td.type-#{elem.val()}").show()

        #Initialize the remove buttons for order items
        $(document).on 'click', '.order-item .glyphicon-remove', () ->
          $(@).parents('.order-item').remove()


    #
    # Initializes the jQuery UI sortable for select/order by/... columns
    #
      initColumnSortables: () ->
        $('ul[data-column-sorting]').sortable
          axis: 'y'
          update: (event, ui) ->
            order = $(event.target).find('li').map () ->
              $(@).data('identifier')

            params = dynamicQueries.CSRFdata
              'order_type': $(event.target).data('clause')
              'order':      order.toArray()

            $.post $(event.target).data('url'), params, null, 'script'

    #
    # Toggles column selection and column sorting for a certain clause
    #
      toggleColumnSorting: (orderType) ->
        $("[data-column-order=#{orderType}]").toggle()

    #
    # Shows, hides or updates the condition modal (based on +action+)
    #
      conditionsModal: (action, content) ->
        switch action
          when 'show'
            $('#conditions_modal').modal('show')
          when 'hide'
            $('#conditions_modal').modal('hide')
          when 'update'
            $('#conditions_modal').html(content)
          else
            console.error 'Unknown command.'

      initConditionCreation: () ->
        #First, make the condition rows draggable, so the user can
        #drag them to the condition creation row
        $(".query-column-condition").draggable
          helper: (event) ->
            elem = $(event.currentTarget)
            helperText = elem.data('caption') || elem.text()
            $("<div></div>").html(helperText)

        addOrderItem = (parent, identifier, caption) ->
          elem = $("<li></li>")
          .addClass('order-item')
          .data 'identifier', identifier
          .html caption
          .append $("<span></span>").addClass("glyphicon glyphicon-remove text-danger")

          $(parent).append elem

        #Init the droppable area to set up the conditions
        $('[data-droppable=conditions]').each () ->
          elem = $(@)

          elem.droppable
            hoverClass:  "list-group-item-success"
            activeClass: "list-group-item-info"
            accept: $("[data-clause=#{elem.data('conditionClause')}], [data-connector]")
            drop: (event, ui) ->
              identifier = ui.draggable.data('identifier')
              caption    = ui.draggable.data("caption") || ui.draggable.text()

              if identifier == '()'
                addOrderItem @, '(', '('
                addOrderItem @, ')', ')'
              else
                addOrderItem @, identifier, caption

        #But wait, there's more! The droppable area is also... a sortable!
        $('[data-droppable=conditions]').sortable()

      updateConditionOrder: (url) ->
        identifiers = {}

        $('[data-droppable=conditions]').each () ->
          identifiers[$(@).data('conditionClause')] = $(@).find('li').map () ->
            $(@).data('identifier')
          .toArray()

        params = dynamicQueries.CSRFdata
          order: identifiers

        $.post url, params, null, 'script'


$(document).ready () ->
  dynamicQueries.loadCSRF()
