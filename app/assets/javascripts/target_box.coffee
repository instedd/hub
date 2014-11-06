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
      return "???" unless $scope.schema
      $scope.schema[key].type.kind || $scope.schema[key].type

    $scope.input_type = (key) ->
      return "text" unless $scope.schema
      res = $scope.schema[key].type
      res = 'number' if res == 'float' || res == 'integer'
      res = 'text' if res == 'string'
      res

    $scope.is_struct = (key) ->
      return false unless $scope.schema
      $scope.schema[key].type.kind == 'struct'

    $scope.is_mapped = (prop) ->
      Object.prototype.toString.call(prop) == '[object Array]'

    $scope.remove_mapping = (key) ->
      $scope.model.members[key] = {type: 'literal', value: null}

    $scope.dropOverMember = (key, path) ->
      $scope.model.members[key] = path

