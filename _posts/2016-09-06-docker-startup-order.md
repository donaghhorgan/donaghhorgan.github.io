---
title: Strategies for controlling service startup order with Docker Compose
date: '2016-09-06 19:00:00'
layout: post
tags:
  - docker
---

As of version 1.6.0, [Docker Compose](https://docs.docker.com/compose/) supports a [`depends_on`](https://docs.docker.com/compose/compose-file/#depends-on) option that allows you to specify dependencies between the various services that you have defined. For instance, if we specify that service B depends on service A, then Compose will start service A first, and then service B. This can be useful in some situations, but  it's not a universal solution and its simplicity can be misleading[^1].

Take, for example, a scenario where we have a service called `api` representing a REST API that we have written and a service called `db` representing a database that the API queries ([Postgres](https://hub.docker.com/_/postgres/), for instance). Using [version 2](https://docs.docker.com/compose/compose-file/#version-2) of the Compose file format, we can write this as:

```yaml
version: '2'

services:
  api:
    build: .
    ...
  db:
    image: postgres
    ...
```

Typically, we'll want the database to be up and running before starting the API service, so that we don't end up in a situation where a user makes a request to the API, but no database is available for it to query.

Using the `depends_on` option, we can ensure that the `db` service is started before the `api` service by modifying our `docker-compose.yml` file, as follows:

```yaml
version: '2'

services:
  api:
    build: .
    depends_on: db
    ...
  db:
    image: postgres
    ...
```

While this might look like it has solved the problem, it hasn't. Docker has no knowledge of how long applications within containers take before they can be considered "ready". All it can do is start services in a given order.

To illustrate the point, consider the hypothetical situation where the initialisation of the database application within the `db` container is delayed for some reason beyond our control (e.g. a CPU intensive task being run on the Docker host machine). Even though the `api` service is started after the `db` service, there is now a chance that it will enter its "ready" state before the database has become available, resulting in undesirable behaviour.

Of course, this is all noted in the [official Compose documentation](https://docs.docker.com/compose/startup-order/). The question is, what can be done about it?

# Application-specific polling

When waiting for a specific application to become available, it might seem like the most logical thing to do is to use an application-specific solution. For instance, we could write some code to run in service B that waits for the application in service A to fulfil one or more predefined conditions before  allowing the main application in service B to start. This way, there is a strict guarantee that the application in service A is verified as available before the application in service B is allowed to start.

An example of this is given in the [official Compose documentation](https://docs.docker.com/compose/startup-order/), where a wrapper script is used to check that a Postgres database (running in a separate container) is ready to accept commands before running the rest of the application. I've put together a quick demo of this [here](https://github.com/donaghhorgan/compose-sync-examples).

Still, application-specific polling has some disadvantages. Firstly, we must write wrapper scripts for each new application that we want to wait for. Furthermore, as each script we must write is application-specific, each will have its own dependencies (e.g. psql in the example above) which will have to be bundled into each container that the script is used with. If the size of a container is small relative to the size of the wrapper script and its dependencies, this could lead to bloat, especially if we want to wait for more than one application within a single container.

We also have to deal with the fact that scripts that are written to run on one container OS may not run correctly (or at all) on another. For instance, if a script depends on some utility (e.g. psql) this will need to be available on each container OS that we want to use the script with. While adding these utilities is generally not difficult, it might require tedious compilation from source on certain OS flavours that don't provide packages. Consequently, support for a single script that works across all possible container operating systems is not guaranteed.

Of course, if you have access to the source code of the application in the container, then you can always extend it to wait for the dependent service. In most cases, it is likely that you will be able to do this without including any additional dependencies (e.g. if you've written a Java application that already interacts with a Postgres database, and so already includes the required JARs), and so the container bloat can be kept to a minimum. However, unless all of your container applications are developed in the same language, you'll find that this approach is also limited.

# Port polling

Knowing that a specific application is running can be valuable, but in lots of cases we'll settle for knowing that *some* application is running. After all, as system designers, we can encode certain assumptions about how different components of our system will operate in practice: if we design a system with a database service, it's reasonable to assume that responses from the host and port corresponding to that service can be interpreted as responses from the database application running within it.

In practice, this can be quite a powerful assumption to make because port polling is not application-specific. This means that we can use generic utilities, such as [wait-for-it](https://github.com/vishnubob/wait-for-it) and [dockerize](https://github.com/jwilder/dockerize), to implement port polling in our services (I've put together some demos [here](https://github.com/donaghhorgan/compose-sync-examples)). Both tools are small in size (<3MB), so container bloat is minimal, although wait-for-it does depend on bash, so you will need to install this in your container if you don't already have it.

Of course, there are some limitations to these tools too. For instance, if we have to wait for a third party application, and it starts listening on a port before it can be considered available, port polling is not a reliable method for determining its readiness. Moreover, if we want to wait for an application that doesn't communicate over a network, port polling (and application-specific polling, for that matter) won't work at all.

# File system polling

Consider what happens when we implement a reverse proxy that dynamically updates its configuration as new services are started. Let's assume that we're using [Nginx](https://hub.docker.com/_/nginx/) as our reverse proxy. We can update our earlier example as follows:

```yaml
version: '2'

services:
  api:
    build: ...
    ...
  db:
    image: postgres
    ...
  rproxy:
    image: nginx
    ...
```

While we could use port polling here, and it would work, the initialisation of Nginx becomes much more complicated: as we add more services, we must tell Nginx to wait for each one. While it is possible to do this within the context of the `docker-compose.yml` file (by adding an entrypoint wrapper script to the `nginx` image and adjusting the `command` on the `rproxy` service, say), we'll have to adjust this configuration each time we add a new service.

There is an alternative solution though: instead of making Nginx wait for each of the services it depends on, we can instead invert the relationship and make each dependent request the reverse proxy service from Nginx.

One simple way to do this is to implement a file polling system[^2] with [`inotifywait`](http://linux.die.net/man/1/inotifywait). In our reverse proxy example, we can do this by sharing a volume between all the services that require a reverse proxy service:

```yaml
version: '2'

services:
  api:
    build: ...
    volumes:
      - rproxy-requests:/var/rproxy
    ...
  db:
    image: postgres
    ...
  rproxy:
    build: .
    volumes:
      - rproxy-requests:/var/rproxy
    ...

volumes:
  rproxy-requests: {}
```

Inside the Nginx container, we'll need to set up `inotifywait` to watch the `/var/rproxy` directory for new requests. Then, each time we add a service that requires reverse proxying, all we need to do is map the `rproxy-requests` volume to that container and have the service [create a configuration file](https://github.com/philipz/docker-nginx-inotify) in the volume that requests the reverse proxy service. Take a look at the demo [here](https://github.com/donaghhorgan/compose-sync-examples) for more detail.

File system polling avoids the use of networking entirely, but at the cost of sharing a single volume among many different containers, leading to a situation where two or more containers may attempt to write to a single file on the shared volume simultaneously. A further disadvantage is that, by allowing direct access to the file system of another container, we might unintentionally introduce security holes, where one service can run privileged commands in another. Still, if implemented with sufficient consideration, file system polling can be an effective way to reduce the complexity of waiting for diverse sets of applications.

# Use a service status broker

Finally, we could use a broker to broadcast updates about service statuses to all interested parties. A typical Compose file for this pattern looks like this:

```yaml
version: '2'

services:
  db:
    image: postgres
    ...
  db_watcher:
    build: ...
    links:
      - db
      - broker
  broker:
    build: ...
  my_service:
    build: ...
    links:
      - broker
  my_other_service:
    build: ...
    links:
      - broker
  ...
```

Here, we have a service called `db_watcher` that implements one of the above techniques to determine when the application in the `db` container has started. The `db_watcher` service then posts an update to the `broker`, which in turn forwards this notification to other interested services (e.g. `my_service`, `my_other_service`).

One advantage of this is that we only have to implement the actual application wait logic once, in the `db_watcher` container. We can also use the same broker to pass multiple notifications, so the pattern scales quite nicely if we have more than one service to wait for.

Clearly, we will need to implement some logic within each dependent service to listen for notifications from the broker, but this is a relatively small drawback, given that we can choose the form of the broker ourselves. One obvious choice is [MQTT](http://mqtt.org), for which numerous [clients](https://github.com/mqtt/mqtt.github.io/wiki/libraries) have been written, across a variety of different platforms. To see an example of this in action, check out the demo [here](https://github.com/donaghhorgan/compose-sync-examples).

# Summary

There are numerous strategies for controlling service startup order with Docker Compose, and each has its advantages and disadvantages. When waiting for a service that doesn't communicate over a network, *file system polling* seems like the best choice. However, for any other kind of service, the choice of which strategy to use in a given situation depends on the context of the application being developed. Here are a few rules of thumb:

- If the number of services to wait for is small and the number of dependent services is also small, then *application-specific polling* may be a good choice, as the amount of development overhead is also likely to be small.
- If the number of services to wait for is small and the number of dependent services is large, then *port polling* may be a good choice, as a generic solution can be used in each dependent service, which should minimise the total development overhead.
- If the number of services to wait for is large and the number of dependent services is also large, then using a *service broker* pattern may be a good choice, as a centralised entity can be used to transfer notifications to all dependent services, avoiding the need to create solutions for each application being waited on within each dependent service.


[^1]: To be fair to the [official documentation](https://docs.docker.com/compose/compose-file/#depends-on), this is well flagged.
[^2]: Inspired by [this](https://ryanfb.github.io/etc/2015/09/24/dependencies_for_docker-compose_with_inotify.html) and [this](http://techarena51.com/index.php/inotify-tools-example/).
