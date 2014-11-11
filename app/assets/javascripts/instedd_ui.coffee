angular
.module('InSTEDD.UI', [])
.config ($httpProvider) ->

  showError = (message) ->
    $.status.showError(message)
    alert(message) if $('.modal-backdrop').length > 0 # if a modal is shown

  $httpProvider.interceptors.push ($q) ->
    requestError: (rejection) ->
      showError('An error has occurred. Please reload the page and try again.')
      return $q.reject(rejection);

    responseError: (rejection) ->
      showError('An error has occurred. Please reload the page and try again.')
      return $q.reject(rejection);

