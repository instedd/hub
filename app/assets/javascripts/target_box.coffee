angular
.module('InSTEDD.Hub.TargetBox', [])

.directive 'ihTargetBox', ->
  restrict: 'E',
  scope:
    model: '='
    schema: '='
    prefix: '='
  templateUrl: '/angular/target_box.html'
  controller: ($scope) ->
    $scope.human_type = (key) ->
      $scope.schema[key].type.kind || $scope.schema[key].type

    $scope.is_struct = (key) ->
      $scope.schema[key].type.kind == 'struct'

    $scope.is_mapped = (prop) ->
      Object.prototype.toString.call(prop) == '[object Array]'

    $scope.remove_mapping = (key) ->
      $scope.model.members[key] = {type: 'literal', value: null}

    $scope.dropOverMember = (key, path) ->
      # console.log(key, path)
      $scope.model.members[key] = path

