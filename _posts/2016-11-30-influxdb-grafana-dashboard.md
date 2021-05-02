---
title: Rolling your own analytics dashboard with InfluxDB, Grafana and Docker
date: '2016-11-30 23:00:00'
layout: post
tags:
  - docker
  - influxdb
  - grafana
  - analytics
  - cork
  - parking
  - open-data
---

For a [pet project](https://github.com/donaghhorgan/cork-parking-dashboard), I decided to build my own dashboard for charting and analysing time series metrics. There are lots of options out there for doing this. For data aggregation and querying, you can use [Graphite](https://graphiteapp.org/), [Prometheus](https://prometheus.io/), [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/), [OpenTSDB](http://opentsdb.net/), [Riak](http://basho.com/products/riak-ts/), [DalmatinerDB](https://dalmatiner.io/) and more. And for visualisation, there's Graphite (again), [Grafana](http://grafana.org/), [Kibana](https://www.elastic.co/products/kibana), [Chronograf](https://www.influxdata.com/time-series-platform/chronograf/) and others.

Figuring out which combination of tools to use can seem overwhelming at first, but you can narrow down the candidates a little by defining the problem. In my case, I had some time series carpark capacity data that I wanted to aggregate and chart and maybe run some predictive models on[^1]. I only had a handful of metrics, so scale wasn't that important. I also wanted to be able to get up and running as quickly as possible.

Given this, InfluxDB seemed like a good choice for data storage.  With the exception of Prometheus, it had the most complete set of [analysis functions](https://docs.influxdata.com/influxdb/v1.0/query_language/functions/) available out of the box[^2]. And, unlike Prometheus, it has a simple HTTP API for inserting and querying metrics[^3], which means you don't have to go to the hassle of creating a [Pushgateway](https://prometheus.io/docs/instrumenting/pushing/) to get started.

I decided to go with Grafana as a dashboard frontend, partially because it supports InfluxDB out of the box, but also because it appeared to be the most feature rich platform of all those I considered[^4]. Its [plugin ecosystem](https://grafana.net/plugins) is also quite mature, and allows you to add extra functionality (like [map widgets](https://cork.donagh.io/dashboard/db/carparks)) easily.

# Building the dashboard

As InfluxDB and Grafana are both published as official Docker images, it seemed natural to tie them together using [Docker Compose](https://docs.docker.com/compose/). This way, I'd have a reusable base project to build future dashboards from. Integrating the services required some slight tweaking, but in the end I had a skeleton project that ran InfluxDB, connected Grafana to it and automatically deployed whatever data sources and dashboards I wanted.

The basic project setup looks like this:

    .
    ├── configuration.env
    ├── docker-compose.yml
    ├── influxdb
    │   ├── Dockerfile
    │   └── entrypoint.sh
    └── grafana
        ├── Dockerfile
        ├── entrypoint.sh
        ├── datasources
        │  └── default.json
        └── dashboards
           └── ...

The files in the root directory define the service architecture (`docker-compose.yml`) and overall project configuration (`configuration.env`), while those in the `influxdb` and `grafana` subdirectories define the behaviour of the services themselves. The `grafana/datasources` directory holds a default JSON data source description (to connect to InfluxDB), although you can add others if you want to deploy them automatically on initialisation. The `grafana/dashboards` directory works the same way, although there aren't any defaults here because dashboards are generally application-specific.

## Configuration

The `configuration.env` file defines environment variables that are shared amongst the containers by Docker Compose. Both [InfluxDB](https://docs.influxdata.com/influxdb/v1.1/administration/config/#environment-variables) and [Grafana](http://docs.grafana.org/installation/configuration/#using-environment-variables) support configuration via environment variables, so this is a quick and convenient way to initialise service defaults.

At a minimum, you'll need login credentials for InfluxDB and Grafana and a default InfluxDB database for Grafana to connect to, although this can be expanded upon as required. Something like this should do the trick:

```shell
#
# Grafana options
#
GF_SECURITY_ADMIN_USER=<GRAFANA_USER>
GF_SECURITY_ADMIN_PASSWORD=<GRAFANA_PASSWORD>

#
# InfluxDB options
#
INFLUX_USER=<INFLUX_USER>
INFLUX_PASSWORD=<INFLUX_PASSWORD>
INFLUX_DB=<DEFAULT_INFLUX_DB>
```

## Docker Compose

The service architecture is defined by the `docker-compose.yml` file in the root of the project. The exact structure will vary according to your deployment platform, but it doesn't have to be complicated - here's a minimal example:

```yaml
version: '2'

services:
  influxdb:
    build: influxdb
    env_file: configuration.env
    volumes:
      - influxdb_data:/var/lib/influxdb
  grafana:
    build: grafana
    env_file: configuration.env
    links:
      - influxdb
    ports:
      - '80:3000'
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  grafana_data: {}
  influxdb_data: {}
```

The Compose file does a number of things:

- It defines services for InfluxDB and Grafana, allowing you to manage each separately.
- It sets the environment variables defined in the `configuration.env` file within each container, so that you can use them to initialise the services.
- It defines [data volumes](https://docs.docker.com/compose/compose-file/#volumes-volumedriver) for both InfluxDB and Grafana, so that you can persist all of your mutable state to a convenient location.
- It creates a link between the InfluxDB service and the Grafana service using the [links](https://docs.docker.com/compose/compose-file/#links) option. This way, you can reference InfluxDB using the hostname `influxdb` directly from within the Grafana container.
- It maps port 3000 on the Grafana container to port 80 on the host OS.

## InfluxDB

Creating the InfluxDB container is pretty simple. InfluxDB is [already available](https://hub.docker.com/_/influxdb/) as an image on Docker Hub, so all you need to do is derive your image from this and make a few customisations. Here's a sample Dockerfile:

```docker
FROM influxdb:1.0.1-alpine

WORKDIR /app
COPY entrypoint.sh ./
RUN chmod u+x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
```

You might notice that the `ENTRYPOINT` here is set to run the `entrypoint.sh` shell script. This is a [common design pattern](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#/entrypoint) for containers where you want to run some initialisation code before starting the main application. In this case, you'll need the entrypoint script to wire InfluxDB so that the username and password you set in `configuration.env` are set as the default administrator credentials:

```shell
#!/usr/bin/env sh

if [ ! -f "/var/lib/influxdb/.init" ]; then
  exec influxd $@ &

  until wget -q "http://localhost:8086/ping" 2> /dev/null; do
    sleep 1
  done

  influx -host=localhost -port=8086 \
    -execute="CREATE USER ${INFLUX_USER} " \
             "WITH PASSWORD ${INFLUX_PASSWORD} " \
             "WITH ALL PRIVILEGES"

  touch "/var/lib/influxdb/.init"

  kill -s TERM %1
fi

exec influxd $@
```

This deserves a little more explanation. First, the script checks whether the file `/var/lib/influxdb/.init` exists or not. If it does, great — we just start InfluxDB. If it doesn't, then the script starts InfluxDB, waits for it to come online (using [`wget`](https://linux.die.net/man/1/wget)), sets the default administrator credentials and then creates the `/var/lib/influxdb/.init` file. This way, the administrator credentials are set the first time the container is started, but not on subsequent starts.

## Grafana

As Grafana also have an official image [on Docker Hub](https://hub.docker.com/r/grafana/grafana/), the image setup is similar to above:

```docker
FROM grafana/grafana:3.1.1

RUN apt-get update && \
    apt-get install -y \
        curl \
        gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY dashboards /etc/grafana/dashboards
COPY datasources /etc/grafana/datasources

WORKDIR /app
COPY entrypoint.sh ./
RUN chmod u+x entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
```

This Dockerfile is a little more complicated than before. First off, [`curl`](https://linux.die.net/man/1/curl) and [`envsubst`](https://linux.die.net/man/1/envsubst) are installed (they're needed for the entrypoint shell script below). Next, the dashboards and data sources that you want Grafana to run by default are copied from your host OS into the container. In the skeleton project layout earlier, there's a default data source and no dashboards, but at some point you'll probably have more, at which point this feature will come in handy. Finally, the container entrypoint is set, in pretty much the same way as with the InfluxDB container.

The entrypoint script itself is also a little more complicated than before:

```shell
#!/usr/bin/env sh

url="http://$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD@localhost:3000"

post() {
    curl -s -X POST -d "$1" \
        -H 'Content-Type: application/json;charset=UTF-8' \
        "$url$2" 2> /dev/null
}

if [ ! -f "/var/lib/grafana/.init" ]; then
    exec /run.sh $@ &

    until curl -s "$url/api/datasources" 2> /dev/null; do
        sleep 1
    done

    for datasource in /etc/grafana/datasources/*; do
        post "$(envsubst < $datasource)" "/api/datasources"
    done

    for dashboard in /etc/grafana/dashboards/*; do
        post "$(cat $dashboard)" "/api/dashboards/db"
    done

    touch "/var/lib/grafana/.init"

    kill $(pgrep grafana)
fi

exec /run.sh $@
```

For readability, I defined a HTTP POST function at the top of the file. After this, the entrypoint works just like with InfluxDB: it checks for an initialisation file and runs some one-off setup commands if it's not there. The setup code starts Grafana, waits for it to come online, and posts any data sources and dashboards that were included so that Grafana will run them by default.

Because the entrypoint script uses `envsubst` to parse the data source JSON files, you can use any environment variables you've defined in `configuration.env` in these. For instance, you can create a default data source (`default.json` in the skeleton project structure earlier) like this:

```json
{
  "name": "$INFLUX_DB",
  "type": "influxdb",
  "url": "http://influxdb:8086",
  "access": "proxy",
  "user": "$INFLUX_USER",
  "password": "$INFLUX_PASSWORD",
  "database": "$INFLUX_DB",
  "basicAuth": false
}
```

Then, when Grafana is initialised, it will automatically create a data source for your default InfluxDB database. If you have dashboards that reference this data source, then you just need to include them in the `grafana/dashboards` directory before container initialisation[^5] and they'll automatically get loaded too.

A live demo of the carpark capacity dashboard that I built using [this skeleton framework](https://github.com/donaghhorgan/cork-parking-dashboard) is running at [cork.donagh.io](https://cork.donagh.io).

# Summary

Building your own analytics dashboard with Docker isn't difficult, but it does take time to figure out how the services work and plan their integration. A fear of shell scripting probably won't help either. That being said, once you have a base Compose application, you can reuse it across multiple different projects so, depending on your requirements, the investment in time may be worthwhile.

Despite the variety of InfluxQL queries and Grafana widgets, the combination of InfluxDB and Grafana for data analysis is pretty basic: all you get out of the box is the ability to chart and do (relatively) trivial analysis on metrics. The only predictive modelling function available in InfluxDB - Holt Winters forecasting - [doesn't seem ready](https://cork.donagh.io/dashboard/db/carparks) for the real world just yet[^6] and Grafana lacks the variety of chart types and the depth of customisation available in R, matplotlib and D3. Still, for a small investment in time, you do get a simple, scalable, secure(-able), generally production-ready system. Gluing together bits of scripts to plot your linear regressions somehow seems less attractive.

[^1]: The finished product is in action at [cork.donagh.io](https://cork.donagh.io).
[^2]: You can get even more advanced functionality with the [Kapacitor](https://docs.influxdata.com/kapacitor/v1.1/) add on.
[^3]: There's also good library support in [multiple languages](https://docs.influxdata.com/influxdb/v1.1/tools/api_client_libraries/).
[^4]: As Kibana only supports Elasticsearch as a backend, it was never really a contender to begin with.
[^5]: Of course, you can always just add them manually through the [HTTP API](http://docs.grafana.org/reference/http_api/#dashboards) or through the [UI](http://docs.grafana.org/reference/export_import/#importing-a-dashboard).
[^6]: For something more advanced, it's probably worth considering adding a Kapacitor service with some [user defined functions](https://docs.influxdata.com/kapacitor/v1.1/examples/anomaly_detection/) or just biting the bullet entirely and running your analysis jobs in Spark.
