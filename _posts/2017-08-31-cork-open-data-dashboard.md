---
title: Cork Open Data Dashboard
date: '2017-08-31 21:43:04'
layout: post
tags:
  - open-data
  - influxdb
  - grafana
  - docker
  - projects
  - cork
  - analytics
  - parking
  - holt-winters
---


The [Cork Open Data Dashboard](https://cork.donagh.io) is a visualisation and analysis tool for several of the datasets on Cork City's [open data portal](http://data.corkcity.ie), built with open source tools including [Docker](https://docker.io), [InfluxDB](https://influxdata.com) and [Grafana](https://grafana.com).

The dashboard is essentially an expanded and refined version of the [parking dashboard](https://donagh.io/influxdb-grafana-dashboard/) I developed last year, and covers three[^1] of the core datasets available on the open data portal. All of the source code for this project is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) and available on [GitHub](https://github.com/donaghhorgan/cork-parking-dashboard).

# Parking capacity

The [parking capacity dashboard](https://cork.donagh.io/dashboard/db/carparks) shows the latest parking capacity data from various carparks around Cork City. Historical parking capacity can be viewed by adjusting the dashboard time range, while InfluxDB's built-in [Holt-Winters forecasting](https://docs.influxdata.com/influxdb/v1.3/query_language/functions/#holt-winters) enables the prediction of future parking capacity, up to 24 hours in advance.

By default, the dashboard displays aggregated data for all available carparks, but this can be customised to individual carparks using the drop down menu on the top left of the view.

![carparks](/assets/images/carparks.png)

# Bike share capacity

The [bike share capacity dashboard](https://cork.donagh.io/dashboard/db/bikes) shows the latest [bike share](https://bikeshare.ie/) capacity data from various bike share stations around Cork City. Just like the carpark dashboard, there are future capacity predictions, individual station drill-downs and historical data views (via the time range filter).

![bikes](/assets/images/bikes.png)

# River levels

The [river level dashboard](https://cork.donagh.io/dashboard/db/river-levels) shows the latest water level data from various sample points along the River Lee. Just like the carpark and bike share dashboards, there are future capacity predictions and historical data views.

![river-levels](/assets/images/river-levels.png)

[^1]: Currently, there are just four datasets available: [parking capacity](http://data.corkcity.ie/dataset/parking), [bike share capacity](http://data.corkcity.ie/dataset/coca-cola-zero-bikes), [river levels](http://data.corkcity.ie/dataset/river-lee-levels) and [planning permission applications](http://data.corkcity.ie/dataset/planning-permission).
