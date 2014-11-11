angular
.module('InSTEDD.Hub.Browser', [])

.directive 'ihModal', ->
  restrict: 'A'
  link: (scope, element, attrs) ->
    scope.$on 'modal:show', ->
      $(element).modal('show')
      return #avoid returning dom

    scope.$on 'modal:hide', ->
      $(element).modal('hide')
      return #avoid returning dom

.directive 'ihEntityPicker', ->
  restrict: 'E'
  scope:
    model: '='
    type: '@'
    onChange: '&'
  templateUrl: '/angular/entity_picker.html'
  controller: ($scope) ->
    $scope.openEventDialog = ->
      $scope.$broadcast 'modal:show'
      false

    $scope.acceptEventDialog = ->
      return if !$scope.is_selection_valid()
      $scope.model = $scope.dialog_selection
      $scope.closeEventDialog()
      $scope.onChange()

    $scope.closeEventDialog = ->
      $scope.$broadcast 'modal:hide'

    $scope.eventSelected = (item) ->
      $scope.dialog_selection = item

    $scope.is_selection_valid = ->
      $scope.dialog_selection? && $scope.dialog_selection.type == $scope.type

.directive 'ihEntityBrowser', ->
  restrict: 'E'
  scope:
    onSelect: '&'
  templateUrl: '/angular/entity_browser.html'

.directive 'ihScrollRightOn', ->
  restrict: 'A'
  link: (scope, element, attrs) ->
    scope.$on attrs.ihScrollRightOn, ->
      element.animate({scrollLeft: element[0].scrollWidth}, 100)

.controller 'EntityBrowserCtrl', ($scope, $rootScope, $http) ->
  connectors = []

  $scope.$on 'entitybrowser:loading', ->
    $scope.loading_new_column = true
  $scope.$on 'entitybrowser:loaded', ->
    $scope.loading_new_column = false

  $scope.$emit('entitybrowser:loading')
  $http.get('/connectors.json').success (data) ->
    for c in data
      c['__type'] = 'connector'
      connectors.push(c)
    $scope.$emit('entitybrowser:loaded')

  $scope.columns = [connectors]
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
    $scope.onSelect()({connector: $scope.selection[0].guid, path: item.path, type: item.__type})

  $scope.is_in_selection = (item) ->
    $scope.column_index < $scope.selection.length &&
    $scope.selection[$scope.column_index] == item

  $scope.is_selected = (item) ->
    $scope.is_in_selection(item) && $scope.column_index == $scope.selection.length - 1

  $scope.is_child_selected = (item) ->
    $scope.is_in_selection(item) && $scope.column_index != $scope.selection.length - 1

  get_children = (item) ->
    res = []

    $scope.$emit('entitybrowser:loading')
    $http.get(item.reflect_url).success (data) ->

      for prop, schema of data.properties
        schema['__type'] = schema.type
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

      $scope.$emit('entitybrowser:loaded')

    res

entity_to_items = (entity) ->
  { name: prop } for prop, value of entity
