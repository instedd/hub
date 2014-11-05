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
