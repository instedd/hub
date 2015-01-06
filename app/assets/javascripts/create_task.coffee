angular
.module('CreateTaskApp', ['InSTEDD.UI', 'InSTEDD.Hub.Browser', 'InSTEDD.Hub.SourceBox', 'InSTEDD.Hub.TargetBox', 'ang-drag-drop'])

.controller 'CreateTaskCtrl', ($scope, $http) ->

  # hacks for testing. ONA Connec
  # $scope.event = {
  #   connector: '04b1fd47-329f-79e7-8e8a-704ef0a4194c'
  #   path: 'forms/10464/$events/new_data'
  # }

  # $scope.action = {
  #   connector: '1d5fc682-a580-6337-dfd9-f2361238b76f'
  #   path: 'indices/mbuilder_application_1/types/05f222da-48f3-4a8b-8123-fce18e457fb7/$actions/insert'
  # }

  $scope.$watch 'event', (event) ->
    $scope.event_json = JSON.stringify(event)

  $scope.$watch 'action', (action) ->
    $scope.action_json = JSON.stringify(action)

  $scope.$watch 'binding', (binding) ->
    $scope.binding_json = JSON.stringify(binding)
  , true

  reflect_url = (model) ->
    "/api/reflect/connectors/#{model.connector}/#{model.path}"

  $scope.$watch 'event', (event) ->
    unless event? && event.connector && event.path
      $scope.event_reflect = null
      return

    $http.get(reflect_url(event)).success (data) ->
      $scope.event_reflect = data

  action_changed_by_user = false
  $scope.updateBinding = ->
    action_changed_by_user = true

  $scope.$watch 'action', (action) ->
    unless action? && action.connector && action.path
      $scope.action_reflect = null
      $scope.binding = null if action_changed_by_user
      return

    $http.get(reflect_url(action)).success (data) ->
      $scope.action_reflect = data

      if action_changed_by_user
        # TODO maybe try to keep as much mappings as possible
        $scope.binding = default_binding({type: {kind: 'struct', members: $scope.action_reflect.args}})

  default_binding = (object) ->
    if object.type?.kind == 'struct'
      res = {
        type: "struct"
        label: null
        members: { }
      }

      for key, value of object.type.members
        res.members[key] = default_binding(value)

      res
    else
      {
        type: "literal"
        value: null
        label: object.label
      }
