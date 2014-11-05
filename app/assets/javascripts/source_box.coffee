angular
.module('InSTEDD.Hub.SourceBox', [])

.directive 'ihSourceBox', ->
  restrict: 'E',
  scope:
    model: '='
    prefix: '='
  templateUrl: '/angular/source_box.html'
  controller: ($scope) ->
    $scope.human_type = (prop) ->
      prop.type?.kind || prop.type || prop

    $scope.is_struct = (prop) ->
      prop.type?.kind == 'struct'

    $scope.is_array = (prop) ->
      prop.type?.kind == 'array'

    $scope.selected = (key) ->
      console.log($scope.path(key))

    $scope.path = (key) ->
      # build the path from parents source_box
      (if $scope.$parent.path?
        $scope.$parent.path($scope.prefix)
      else
        []).concat([key])
