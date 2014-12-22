angular
.module('ApiPickerApp', ['InSTEDD.UI', 'InSTEDD.Hub.Browser'])
.controller 'ApiPickerCtrl', ($scope, $http) ->

  # $scope.type = 'entity_set' | 'action' | 'event'
  $scope.selection = null

  $scope.entitySetSelected = (item, parents) ->
    console.log(item, parents)
    $scope.selection = {
      item: item
      parents: parents
    }

  caller = null
  source = null
  origin = null

  $scope.closePicker = () ->
    data = {
      target: source,
      message:"selected",
      path: "connectors/#{$scope.selection.item.connector}/#{$scope.selection.item.path}",
      selection: $scope.selection
    }
    caller.postMessage(JSON.stringify(data), origin)

  listener = (event) ->
    data = JSON.parse(event.data)
    if (data.message == "waiting")
      caller = event.source
      source = data.source
      origin = event.origin
      event.source.postMessage(JSON.stringify({target: data.source, message:"loaded"}), event.origin)

  if (window.addEventListener)
    window.addEventListener("message", (e) =>
      listener(e)
    , false)
  else
    window.attachEvent("onmessage", (e) =>
      listener(e)
    )
