window.dynamicQueries = {
  csrf: {},
  loadCSRF: function() {
    dynamicQueries.csrf.param = jQuery('meta[name=csrf-param]').attr("content");
    return dynamicQueries.csrf.token = jQuery('meta[name=csrf-token]').attr("content");
  },
  CSRFdata: function(data) {
    if (data == null) {
      data = {};
    }
    data[dynamicQueries.csrf.param] = dynamicQueries.csrf.token;
    return data;
  },
  actions: {
    show: {
      init: function() {
        return $("ul.sorting-list").sortable({
          axis: 'x',
          items: "li:not(.no-sorting)"
        });
      }
    },
    "new": {
      init: function() {
        $('input[type=checkbox]').click(function() {
          return dynamicQueries.actions["new"].handleCheckbox(this);
        });
        $('input[type=radio]').click(function() {
          return dynamicQueries.actions["new"].handleRadio(this);
        });
        return $('input[type=radio]:checked').each(function() {
          return dynamicQueries.actions["new"].handleRadio(this);
        });
      },
      handleCheckbox: function(elem) {
        if ($(elem).prop('checked')) {
          return $(elem).parents('tr').addClass('info');
        } else {
          return $(elem).parents('tr').removeClass('info');
        }
      },
      handleRadio: function(elem) {
        var checkbox, row, table;
        row = $(elem).parents('tr');
        table = $(elem).parents('table');
        checkbox = row.find('input[type=checkbox]');
        table.find('tr').removeClass('success');
        table.find('input[type=checkbox]').prop('readonly', false);
        table.find('input[type=checkbox]').each(function() {
          return dynamicQueries.actions["new"].handleCheckbox(this);
        });
        row.addClass('success').removeClass('info');
        checkbox.prop('readonly', true);
        return checkbox.prop('checked', true);
      }
    },
    associations: {
      lowermostBottom: 0,
      updatePositionsUrl: null,
      connections: [],
      init: function(url, connections) {
        return $(document).ready(function() {
          dynamicQueries.actions.associations.updatePositionsUrl = url;
          dynamicQueries.actions.associations.connections = connections;
          dynamicQueries.actions.associations.initModelDraggables();
          dynamicQueries.actions.associations.setBoxPositions();
          dynamicQueries.actions.associations.resizeCanvas();
          return dynamicQueries.actions.associations.drawAllConnections();
        });
      },
      setBoxPositions: function() {
        return $('#dynamic_queries .model').each(function() {
          var box;
          box = $(this);
          if (box.data('positionTop')) {
            box.css('top', box.data('positionTop'));
          }
          if (box.data('positionLeft')) {
            return box.css('left', box.data('positionLeft'));
          }
        });
      },
      initModelDraggables: function() {
        return jsPlumb.draggable($('#dynamic_queries .model'), {
          handle: '.panel-heading',
          scroll: true,
          drag: function(event, ui) {
            var container, containerRightBorder;
            container = $('#dynamic_queries .model-canvas');
            containerRightBorder = container.position().left + container.width();
            if (ui.position.left < container.position().left) {
              ui.position.left = container.position().left;
            }
            if (ui.position.top < container.position().top) {
              ui.position.top = container.position().top;
            }
            if (ui.position.left > (containerRightBorder - ui.helper.outerWidth())) {
              return ui.position.left = containerRightBorder - ui.helper.outerWidth();
            }
          },
          stop: function(event, ui) {
            var positions;
            dynamicQueries.actions.associations.resizeCanvas();
            positions = {};
            $('#dynamic_queries .model').each(function() {
              return positions[$(this).data('modelName')] = [$(this).position().top, $(this).position().left];
            });
            return $.post(dynamicQueries.actions.associations.updatePositionsUrl, dynamicQueries.CSRFdata({
              'positions': positions
            }), null, 'script');
          }
        });
      },
      resizeCanvas: function() {
        dynamicQueries.actions.associations.updateLowermostBottom();
        return $('#dynamic_queries .model-canvas').css('height', dynamicQueries.actions.associations.lowermostBottom);
      },
      updateLowermostBottom: function() {
        var canvasTop, newBottom;
        canvasTop = $('#dynamic_queries .model-canvas').position().top;
        newBottom = 0;
        $('#dynamic_queries .model').each(function() {
          var relativeBottom;
          relativeBottom = $(this).position().top + $(this).height() - canvasTop;
          return newBottom = Math.max(newBottom, relativeBottom);
        });
        return dynamicQueries.actions.associations.lowermostBottom = newBottom;
      },
      drawConnection: function(connection) {
        var dest, source;
        source = jsPlumb.addEndpoint($(connection.source), {
          isSource: true,
          anchor: dynamicQueries.actions.associations.dynamicAnchors(connection),
          endpoint: [
            "Dot", {
              radius: 5
            }
          ]
        });
        dest = jsPlumb.addEndpoint($(connection.target), {
          isTarget: true,
          anchor: "Continuous",
          endpoint: "Blank"
        });
        return jsPlumb.connect({
          'source': source,
          'target': dest,
          connector: "StateMachine",
          paintStyle: {
            lineWidth: 3,
            strokeStyle: "#D9EDF7"
          },
          hoverPaintStyle: {
            strokeStyle: "#C4E3F3"
          },
          overlays: [
            [
              "PlainArrow", {
                location: 1,
                width: 20,
                length: 12
              }
            ], [
              "Label", {
                'label': connection.label,
                cssClass: "connection-label"
              }
            ]
          ]
        });
      },
      clearConnections: function() {
        return jsPlumb.reset();
      },
      redrawConnections: function(newConnections) {
        if (newConnections != null) {
          dynamicQueries.actions.associations.connections = newConnections;
        }
        dynamicQueries.actions.associations.clearConnections();
        return dynamicQueries.actions.associations.drawAllConnections();
      },
      drawAllConnections: function() {
        return $.each(dynamicQueries.actions.associations.connections, function() {
          return dynamicQueries.actions.associations.drawConnection(this);
        });
      },
      dynamicAnchors: function(connection) {
        var verticalCenter;
        verticalCenter = ($(connection.association).position().top + ($(connection.association).height() / 2)) / $(connection.source).height();
        return [[0, verticalCenter, -1, 0], [1, verticalCenter, 1, 0]];
      }
    },
    columns: {
      init: function(url, connections) {
        return $(document).ready(function() {
          dynamicQueries.actions.associations.updatePositionsUrl = url;
          dynamicQueries.actions.associations.connections = connections;
          dynamicQueries.actions.associations.initModelDraggables();
          dynamicQueries.actions.associations.setBoxPositions();
          dynamicQueries.actions.associations.resizeCanvas();
          return dynamicQueries.actions.columns.drawAllConnections();
        });
      },
      drawConnection: function(connection) {
        var dest, source;
        source = jsPlumb.addEndpoint($(connection.source), {
          isSource: true,
          anchor: "Continuous",
          endpoint: [
            "Dot", {
              radius: 5
            }
          ]
        });
        dest = jsPlumb.addEndpoint($(connection.target), {
          isTarget: true,
          anchor: "Continuous",
          endpoint: "Blank"
        });
        return jsPlumb.connect({
          'source': source,
          'target': dest,
          connector: "StateMachine",
          paintStyle: {
            lineWidth: 3,
            strokeStyle: "#D9EDF7"
          },
          hoverPaintStyle: {
            strokeStyle: "#C4E3F3"
          },
          overlays: [
            [
              "PlainArrow", {
                location: 1,
                width: 20,
                length: 12
              }
            ], [
              "Label", {
                'label': connection.label,
                cssClass: "connection-label"
              }
            ]
          ]
        });
      },
      redrawConnections: function(newConnections) {
        if (newConnections != null) {
          dynamicQueries.actions.associations.connections = newConnections;
        }
        dynamicQueries.actions.associations.clearConnections();
        return dynamicQueries.actions.columns.drawAllConnections();
      },
      drawAllConnections: function() {
        return $.each(dynamicQueries.actions.associations.connections, function() {
          return dynamicQueries.actions.columns.drawConnection(this);
        });
      }
    },
    columnOptions: {
      init: function() {
        dynamicQueries.actions.columnOptions.initColumnSortables();
        dynamicQueries.actions.columnOptions.initConditionCreation();
        $(document).on('change', '[data-column-option]', function() {
          var elem, params, value;
          elem = $(this);
          value = elem.val();
          if (elem.attr('type') === 'checkbox') {
            value = elem.prop('checked') ? '1' : '0';
          }
          params = dynamicQueries.CSRFdata({
            'value': value,
            'column_identifier': elem.data('columnIdentifier'),
            'option_name': elem.data('optionName')
          });
          return $.post(elem.data('url'), params, null, 'script');
        });
        $(document).on('change', 'input[type=radio][data-init=show-condition-type]', function() {
          var elem, table;
          elem = $(this);
          table = elem.parents('.modal-body').find('table');
          table.find('td.condition-type').hide();
          return table.find("td.type-" + (elem.val())).show();
        });
        return $(document).on('click', '.order-item .glyphicon-remove', function() {
          return $(this).parents('.order-item').remove();
        });
      },
      initColumnSortables: function() {
        return $('ul[data-column-sorting]').sortable({
          axis: 'y',
          update: function(event, ui) {
            var order, params;
            order = $(event.target).find('li').map(function() {
              return $(this).data('identifier');
            });
            params = dynamicQueries.CSRFdata({
              'order_type': $(event.target).data('clause'),
              'order': order.toArray()
            });
            return $.post($(event.target).data('url'), params, null, 'script');
          }
        });
      },
      toggleColumnSorting: function(orderType) {
        return $("[data-column-order=" + orderType + "]").toggle();
      },
      conditionsModal: function(action, content) {
        switch (action) {
          case 'show':
            return $('#conditions_modal').modal('show');
          case 'hide':
            return $('#conditions_modal').modal('hide');
          case 'update':
            return $('#conditions_modal').html(content);
          default:
            return console.error('Unknown command.');
        }
      },
      initConditionCreation: function() {
        var addOrderItem;
        $(".query-column-condition").draggable({
          helper: function(event) {
            var elem, helperText;
            elem = $(event.currentTarget);
            helperText = elem.data('caption') || elem.text();
            return $("<div></div>").html(helperText);
          }
        });
        addOrderItem = function(parent, identifier, caption) {
          var elem;
          elem = $("<li></li>").addClass('order-item').data('identifier', identifier).html(caption).append($("<span></span>").addClass("glyphicon glyphicon-remove text-danger"));
          return $(parent).append(elem);
        };
        $('[data-droppable=conditions]').each(function() {
          var elem;
          elem = $(this);
          return elem.droppable({
            hoverClass: "list-group-item-success",
            activeClass: "list-group-item-info",
            accept: $("[data-clause=" + (elem.data('conditionClause')) + "], [data-connector]"),
            drop: function(event, ui) {
              var caption, identifier;
              identifier = ui.draggable.data('identifier');
              caption = ui.draggable.data("caption") || ui.draggable.text();
              if (identifier === '()') {
                addOrderItem(this, '(', '(');
                return addOrderItem(this, ')', ')');
              } else {
                return addOrderItem(this, identifier, caption);
              }
            }
          });
        });
        return $('[data-droppable=conditions]').sortable();
      },
      updateConditionOrder: function(url) {
        var identifiers, params;
        identifiers = {};
        $('[data-droppable=conditions]').each(function() {
          return identifiers[$(this).data('conditionClause')] = $(this).find('li').map(function() {
            return $(this).data('identifier');
          }).toArray();
        });
        params = dynamicQueries.CSRFdata({
          order: identifiers
        });
        return $.post(url, params, null, 'script');
      }
    }
  }
};

$(document).ready(function() {
  return dynamicQueries.loadCSRF();
});
