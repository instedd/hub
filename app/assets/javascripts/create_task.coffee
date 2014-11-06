angular
.module('CreateTaskApp', ['InSTEDD.Hub.Browser', 'InSTEDD.Hub.SourceBox', 'InSTEDD.Hub.TargetBox', 'ang-drag-drop'])

.controller 'CreateTaskCtrl', ($scope, $http) ->

  # hacks for testing. ONA Connec
  $scope.event = {
    connector: '04b1fd47-329f-79e7-8e8a-704ef0a4194c'
    path: 'forms/10464/$events/new_data'
  }

  $scope.action = {
    connector: '1d5fc682-a580-6337-dfd9-f2361238b76f'
    path: 'indices/mbuilder_application_1/types/05f222da-48f3-4a8b-8123-fce18e457fb7/$actions/insert'
  }

  reflect_url = (model) ->
    "/connectors/#{model.connector}/reflect/#{model.path}"

  $scope.$watch 'event', (event) ->
    unless event?
      $scope.event_reflect = null
      return

    $http.get(reflect_url(event)).success (data) ->
      $scope.event_reflect = data

  $scope.$watch 'action', (action) ->
    unless action?
      $scope.action_reflect = null
      return

    $http.get(reflect_url(action)).success (data) ->
      $scope.action_reflect = data

  $scope.$watch 'action_reflect', (action_reflect) ->
    unless action_reflect?
      $scope.mapping = null
      return

    $scope.mapping = default_mapping({type: {kind: 'struct', members: action_reflect.args}})


  default_mapping = (object) ->
    if object.type?.kind == 'struct'
      res = {
        type: "struct"
        members: { }
      }

      for key, value of object.type.members
        res.members[key] = default_mapping(value)

      res
    else
      {
        type: "literal"
        value: null
      }
