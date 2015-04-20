[![Stories in Ready](https://badge.waffle.io/instedd/hub.png?label=ready&title=Ready)](https://waffle.io/instedd/hub)
# InSTEDD Hub

Hub is a centralised point for connecting InSTEDD (and other) applications together, both for sharing data and defining IFTTT-like flows based on events and actions. Every kind of application to be connected requires a _connector_; currently the following InSTEDD apps are connected:

* [ACT](https://github.com/instedd/act)
* [mBuilder](https://github.com/instedd/mbuilder)
* [Remindem](https://github.com/instedd/remindem)
* [ResourceMap](https://github.com/instedd/resourcemap)
* [Verboice](https://github.com/instedd/verboice)

Plus the following external apps or services:

* Generic [ElasticSearch](http://elasticsearch.org) instance
* Google Fusion Tables
* Google Spreadsheets
* [ONA](https://ona.io/)
* [RapidPro](https://www.rapidpro.io/)


# Model

Main data entities in Hub.

## Applications

Each application in Hub is uniquely identified by its host and port, such as `verboice.instedd.org`, or `remindem-local.instedd.org:3000` (the latter is especially useful to be set as an alias if developing a Hub connector locally). The services exposed by each application depends on the connector implemented for them.

Main instances of applications, such as `verboice.instedd.org`, are registered in Hub as **shared**, which means that a single connection is established between them and Hub, but any user can configure an interaction with that application. Only admin users can set an application to be shared. Other instances, such as an individual ElasticSearch server, are not shared and belong exclusively to the user who created them.

Hub will connect to shared applications using client credentials via GUISSO, and a plain user/password for non-shared apps.

## Connectors

A connector allows a kind of application (such as any instance of Resourcemap or ElasticSearch) to be connected to hub. It is a connector's responsibility to wrap the application's API to expose in a standardised way the entities, events and actions available.

Once an application is set up, information on the data exposed can be obtained by _reflecting_ on the connector; this info is exposed in `/api/reflect/connectors/CONNECTOR_GUID`, and the resources available can be navigated recursively.

To access the data itself, replace `reflect` by `data` in the URL; to invoke an action, replace `reflect` by `invoke`.

## Entities and Entity Sets

A connector can define entity sets and entities for an application, which can be nested. The connector typically wraps the application's API using this interface, which provides a standard way of accessing resources from other apps. Entity sets can list all entities available, and can even expose certain queries as filters.

## Events

Events are the originators of Tasks. A task is executed when an event is triggered, and the user-defined action is executed. Events can be managed by either a push from the application to hub, or by polling by hub.

In the first case, the application should use the [Hub Client](https://github.com/instedd/ruby-hub_client) gem, which requires a `config/hub.yml` with the connector GUID and secret token, to notify events; whereas in the second, the event itself implements a `poll` method that is invoked every certain number of minutes to check the diff between subsequent states.

Note that only shared applications can push events to hub.

## Actions

Actions are the counterpart of events, they are executed when an event is triggered, and can be configured to use the data provided by the event. A good example is indexing in ElasticSearch (action) the information provided by a Call Finished notification (event) in Verboice.


# Setup

Hub is a Ruby on Rails application, and depends on Postgres for data storage, Redis for jobs queues using Resque and ElasticSearch for storing [Poirot](http://instedd.github.io/poirot/) activities. Deployment is managed with Docker using fig; refer to `fig.yml` for more details on setting up the environment.

## Configuration files

Hub uses [GUISSO](https://github.com/instedd/guisso) for user management. Add a file `config/guisso.yml` with the required information, which can be retrieved when registering the application in the GUISSO server. Note that a local GUISSO instance can also be used.

```yaml
enabled: true
url: http://login-stg.instedd.org
client_id: CLIENT_ID
client_secret: CLIENT_SECRET
```

Gem [rails-config](https://github.com/railsconfig/rails_config) is used for managing hub local settings, so the default values can be overridden by setting up a `config/settings.local.yml` file. The main setting to override when running hub locally is the `host`.

## Registering applications

Applications are identified by host and port, which must be unique. As such, if using a non-local instance of Hub, make sure to register local aliases for whichever applications you are developing, like:

```
127.0.0.1 remindem-yourname.instedd.org
```

If running hub locally, to ensure correct authentication with GUISSO, it is recommended to set up an alias in the `instedd.org` domain for hub, and use local aliases as well for all the application being connected:

```
127.0.0.1 hub-local.instedd.org
127.0.0.1 resourcemap-local.instedd.org
127.0.0.1 login-local.instedd.org
```

