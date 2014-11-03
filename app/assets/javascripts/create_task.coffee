angular
.module('CreateTaskApp', ['InSTEDD.Hub.Browser'])

.controller 'CreateTaskCtrl', ($scope) ->

  console.log($scope.connectors)

  $scope.openEventDialog = ->
    $('#eventModal').modal('show')
    false

  $scope.acceptEventDialog = ->
    $scope.event = $scope.dialog_selected_event
    $scope.closeEventDialog()

  $scope.closeEventDialog = ->
    $('#eventModal').modal('hide')
    false

  $scope.eventSelected = (item) ->
    $scope.dialog_selected_event = item
