angular
.module('InSTEDD.Hub.TargetBox', [])

.directive 'ihTargetBox', ->
  restrict: 'E',
  scope:
    model: '='
    prefix: '='
  templateUrl: '/angular/target_box.html'
  controller: ($scope) ->
    $scope.human_type = (prop) ->
      prop.type?.kind || prop.type || prop

    $scope.is_struct = (prop) ->
      prop.type?.kind == 'struct'

    $scope.is_array = (prop) ->
      prop.type?.kind == 'array'

    $scope.expr = (key) ->
      if $scope.prefix? && $scope.prefix != ''
        "#{$scope.prefix}.#{key}"
      else
       "#{key}"


