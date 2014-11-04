angular
.module('InSTEDD.Hub.Browser', [])

.directive 'ihEntityBrowser', ->
  restrict: 'E'
  scope:
    onSelect: '&'
    connectors: '='
  templateUrl: '/angular/entity_browser.html'

.controller 'EntityBrowserCtrl', ($scope) ->
  for c in $scope.connectors
    c['__type'] = 'connector'
  $scope.columns = [$scope.connectors]
  $scope.selection = []

.controller 'EntityBrowserColumnCtrl', ($scope, $http) ->
  $scope.items = $scope.column
  $scope.column_index = $scope.columns.indexOf($scope.column)

  $scope.open = (item) ->
    $scope.columns.splice($scope.column_index + 1, Number.MAX_VALUE, get_children(item))
    $scope.select(item)

  $scope.select = (item) ->
    $scope.selection.splice($scope.column_index, Number.MAX_VALUE)
    $scope.selection.push item
    $scope.onSelect()(item)

  $scope.is_in_selection = (item) ->
    $scope.column_index < $scope.selection.length &&
    $scope.selection[$scope.column_index] == item

  $scope.is_selected = (item) ->
    $scope.is_in_selection(item) && $scope.column_index == $scope.selection.length - 1

  $scope.is_child_selected = (item) ->
    $scope.is_in_selection(item) && $scope.column_index != $scope.selection.length - 1

  get_children = (item) ->
    res = []
    $http.get(item.reflect_url).success (data) ->

      for prop, schema of data.properties
        schema['__type'] = schema.type.kind
        res.push schema

      for prop, schema of data.entities
        schema['__type'] = 'entity'
        res.push schema

      for prop, schema of data.actions
        schema['__type'] = 'action'
        res.push schema

      for prop, schema of data.events
        schema['__type'] = 'event'
        res.push schema

    res

entity_to_items = (entity) ->
  { name: prop } for prop, value of entity
