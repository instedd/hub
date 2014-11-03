angular
.module('InSTEDD.Hub.Browser', [])

.directive 'ihEntityBrowser', ->
  restrict: 'E'
  templateUrl: '/angular/entity_browser.html'

.controller 'EntityBrowserCtrl', ($scope) ->
  for c in $scope.connectors
    c['__type'] = 'connector'
  $scope.columns = [$scope.connectors]

.controller 'EntityBrowserColumnCtrl', ($scope, $http) ->
  $scope.items = $scope.column
  $scope.column_index = $scope.columns.indexOf($scope.column)

  $scope.open = (item) ->
    $scope.columns.splice($scope.column_index + 1, Number.MAX_VALUE, get_children(item))

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

    res

entity_to_items = (entity) ->
  { name: prop } for prop, value of entity
