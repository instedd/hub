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
      $scope.typename_for_key(key)

    $scope.input_type = (key) ->
      res = $scope.typename_for_key(key)
      res = 'number' if res == 'float' || res == 'integer'
      res = 'text' if res == 'string'
      res

    $scope.is_struct = (key) ->
      return false unless $scope.typename_for_key(key)
      $scope.typename_for_key(key) == 'struct'

    $scope.typename_for_key = (key) ->
      # the type is from model.open[key] (open struct member with typename)
      # or struct (type.kind always has "struct" as value)
      # or typename
      $scope.model.open?[key] || $scope.schema?[key]?.type?.kind || $scope.schema?[key]?.type

    $scope.is_open_struct = (key) ->
      # is open struct if it is a struct defined on the fly
      # of if the schema specified it is open
      $scope.model.open?[key] == 'struct' || $scope.schema?[key]?.type?.open || false

    $scope.can_delete = (key) ->
      $scope.model.open?[key]?

    $scope.remove_member = (key) ->
      return if !$scope.can_delete(key)
      delete $scope.model.members[key]
      delete $scope.model.open[key]

    $scope.new_field = {type: null, name: null}

    $scope.add_field = (type) ->
      $scope.new_field.type = type
      $scope.new_field.name = null

    $scope.new_field_submit = (key) ->
      $scope.model.members[key].members[$scope.new_field.name] = if $scope.new_field.type == 'struct'
          default_binding {type: {kind: 'struct'} }
        else
          default_binding {type: $scope.new_field.type}

      $scope.model.members[key].open ||= {}
      $scope.model.members[key].open[$scope.new_field.name] = $scope.new_field.type

      $scope.new_field_cancel()

    $scope.new_field_key_press = ($event) ->
      $scope.new_field_submit() if ($event.which == 13)

    $scope.new_field_cancel = () ->
      $scope.new_field = {type: null, name: null}

    $scope.is_mapped = (prop) ->
      Object.prototype.toString.call(prop) == '[object Array]'

    $scope.remove_mapping = (key) ->
      $scope.model.members[key] = {type: 'literal', value: null}

    $scope.dropOverMember = (key, path) ->
      $scope.model.members[key] = path

    default_binding = (object) ->
      if object.type?.kind == 'struct'
        res = {
          type: "struct"
          members: { }
        }

        for key, value of object.type.members
          res.members[key] = default_binding(value)

        res
      else
        {
          type: "literal"
          value: null
        }
