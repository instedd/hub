angular
.module('ApiPickerApp', ['InSTEDD.UI', 'InSTEDD.Hub.Browser'])
.controller 'ApiPickerCtrl', ($scope, $http) ->

  $scope.type = 'entityset'
  $scope.selectedItem = null

  $scope.entitySetSelected = (item) ->
    $scope.selectedItem = item

  caller = null
  source = null
  origin = null

  $scope.closePicker = () ->
    data = {target: source, message:"selected", path: "connectors/#{$scope.selectedItem.connector}/#{$scope.selectedItem.path}"}
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
